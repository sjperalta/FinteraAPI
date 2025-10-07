# frozen_string_literal: true

# app/models/contract.rb
# Model representing a contract for a lot, including state management and payment scheduling.
class Contract < ApplicationRecord
  include Notifiable
  include AASM
  has_paper_trail

  # Associations
  belongs_to :lot
  belongs_to :creator, foreign_key: :creator_id, class_name: 'User', optional: true
  belongs_to :applicant_user, class_name: 'User', foreign_key: 'applicant_user_id', optional: true
  has_many_attached :documents
  has_many :payments, dependent: :destroy
  has_many :ledger_entries, class_name: 'ContractLedgerEntry', dependent: :destroy

  # Callbacks
  before_create :set_amounts

  # Validations
  validates :payment_term, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :financing_type, presence: true, inclusion: { in: %w[direct bank cash] }
  validates :reserve_amount, :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :acceptable_documents

  # Scopes
  scope :active_contracts, -> { where(active: true) }
  scope :approved_between, lambda { |start_date, end_date|
                             where(status: STATUS_APPROVED, approved_at: start_date..end_date)
                           }
  scope :with_creator_and_lot, -> { includes(:creator, :lot) }
  scope :pending_approval, -> { where(status: %w[pending submitted]) }
  scope :by_financing_type, ->(type) { where(financing_type: type) }
  scope :by_applicant_user, ->(user_id) { where(applicant_user_id: user_id) }

  # Constants
  STATUS_APPROVED = 'approved'
  STATUS_PENDING = 'pending'
  STATUS_SUBMITTED = 'submitted'
  STATUS_REJECTED = 'rejected'
  STATUS_CANCELLED = 'cancelled'
  STATUS_CLOSED = 'closed'

  # State Machine Definition
  aasm column: :status do
    state :pending, initial: true
    state :submitted
    state :approved
    state :rejected
    state :cancelled
    state :closed

    event :submit do
      transitions from: %i[pending rejected], to: :submitted, guard: :valid_for_submission?
    end

    event :approve do
      transitions from: %i[pending submitted rejected], to: :approved,
                  guard: :can_be_approved?,
                  after: :handle_approval
    end

    event :reject do
      transitions from: %i[pending submitted], to: :rejected, after: :notify_rejection
    end

    event :cancel do
      transitions from: %i[rejected pending submitted], to: :cancelled, after: :handle_cancellation
    end

    event :close do
      transitions from: :approved, to: :closed, after: :handle_closure
    end
  end

  # Public Methods

  def balance
    ledger_entries.total_balance || 0
  end

  def apply_prepayment(amount_paid)
    unless amount_paid.present? && amount_paid.to_d.positive?
      errors.add(:base, 'El monto del prepago debe ser un número positivo.')
      return false
    end

    amount = amount_paid.to_d
    current_balance = balance

    # Do not apply prepayments when there's no pending balance
    if current_balance <= 0
      errors.add(:base, 'El contrato no tiene balance pendiente.')
      return false
    end

    # Prevent overpayment
    if amount > current_balance
      errors.add(:base, 'El monto del prepago excede el balance pendiente del contrato.')
      return false
    end

    # Create ledger entry for prepayment and close if resulting balance is zero or less
    ledger_entries.create!(amount: -amount, description: 'Abono a Capital', entry_type: 'prepayment')
    new_balance = current_balance - amount
    close! if new_balance <= 0 && may_close?

    true
  end

  private

  # Callbacks

  def set_amounts
    self.amount = lot.effective_price
  end

  # State Machine Handlers

  def handle_approval
    record_approval
    Contracts::PaymentCreationService.new(self).call
    notify_approval
  end

  def handle_cancellation
    log_cancellation
    release_lot
    delete_payments
    notify_cancellation
  end

  def handle_closure
    notify_contract_closed
    mark_lot_as_sold
  end

  def acceptable_documents
    return unless documents.attached?

    documents.each do |document|
      errors.add(:documents, 'is too big') unless document.byte_size <= 10.megabytes

      acceptable_types = ['application/pdf', 'image/jpeg', 'image/png']
      errors.add(:documents, 'must be a PDF, JPG, or PNG') unless acceptable_types.include?(document.content_type)
    end
  end

  def valid_for_submission?
    payment_term.present? &&
      financing_type.present? &&
      reserve_amount.present? &&
      down_payment.present? &&
      applicant_user.present?
  end

  def can_be_approved?
    valid_for_submission? && %w[pending submitted rejected].include?(status)
  end

  def record_approval
    update!(
      approved_at: Time.current,
      active: true
    )
  end

  # Notifications

  def notify_contract_closed
    Contracts::ContractNotifier.new(self).notify_closed
  end

  def notify_approval
    Contracts::ContractNotifier.new(self).notify_approved
  end

  def notify_rejection
    Contracts::ContractNotifier.new(self).notify_rejected
  end

  def notify_cancellation
    Contracts::ContractNotifier.new(self).notify_cancelled
  end

  def log_cancellation
    current_user_email = Thread.current[:current_user]&.email || 'system'
    cancellation_log = "Contrato cancelado #{Time.current} por #{current_user_email}"

    self.note = note.present? ? "#{note}\n#{cancellation_log}" : cancellation_log
    save!
  end

  def release_lot
    update!(active: false)
    lot.update!(status: 'available')
  end

  def delete_payments
    payments.destroy_all
  end

  def mark_lot_as_sold
    lot.update!(status: 'sold')
  rescue StandardError => e
    Rails.logger.error "Failed to mark lot ##{lot.id} as sold: #{e.message}"
  end
end
