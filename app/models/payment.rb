# frozen_string_literal: true

# app/models/payment.rb
# Model representing a payment associated with a contract, including state management and notifications.
class Payment < ApplicationRecord
  include AASM
  include Notifiable

  belongs_to :contract
  has_one_attached :document

  # Constants
  PAYMENT_TYPES = %w[reservation down_payment installment full advance].freeze
  VALID_STATUSES = %w[pending submitted paid rejected].freeze

  # Validations
  validates :amount, :due_date, :status, presence: true
  validates :payment_type, presence: true, inclusion: { in: PAYMENT_TYPES }
  validates :status, inclusion: { in: VALID_STATUSES }
  validates :amount, numericality: { greater_than: 0 }
  validates :interest_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # State Machine Definition
  aasm column: :status do
    state :pending, initial: true
    state :submitted
    state :paid
    state :rejected

    # Transition from pending to submitted when receipt is uploaded
    event :submit do
      transitions from: :pending, to: :submitted,
                  guard: :document_attached?,
                  after: :notify_submission
    end

    # Transition from submitted to paid when payment is approved
    # or when the payment is made directly (e.g., cash payment, bank transfer)
    # it should check the balance is 0 or less, then close the contract
    event :approve do
      transitions from: %i[pending submitted], to: :paid,
                  guard: :can_be_approved?,
                  after: :handle_approval
    end

    # Transition from submitted to rejected when payment is rejected
    event :reject do
      transitions from: :submitted, to: :rejected,
                  after: :notify_rejection
    end

    event :undo do
      transitions from: :paid, to: :submitted,
                  after: :handle_undo
    end
  end

  scope :pending, -> { where(status: 'pending') }
  scope :overdue, -> { pending.where('due_date < ?', Date.current).order(:due_date) }

  def notify_overdue_interest(overdue_interest)
    create_notification(
      user: contract.applicant_user,
      title: "Pago Atrasado: #{description}",
      message: "Se ha generado un cargo por mora de #{overdue_interest}.",
      notification_type: 'payment_overdue'
    )
  end

  private

  def document_attached?
    document.attached?
  end

  def can_be_approved?
    contract.present?
  end

  def record_approval_timestamp
    self.approved_at = Time.current
    self.payment_date = Date.current
    self.paid_amount = amount
    save!
  end

  def update_contract_balance
    contract.update_balance(paid_amount)
  end

  def notify_submission
    create_notification(
      user: contract.applicant_user,
      title: 'Actualización Pago',
      message: "Pago ##{id} a sido enviado para aprobación.",
      notification_type: 'payment_submitted'
    )
  end

  def notify_approval
    notify_user_and_admins(
      user: contract.applicant_user,
      title: 'Actualización Pago',
      message: "Pago ##{id} ha sido aprobado, monto: #{paid_amount}.",
      notification_type: 'payment_approved'
    )
  end

  def notify_rejection
    create_notification(
      user: contract.applicant_user,
      title: 'Actualización Pago',
      message: "Pago ##{id} ha sido rechazado.",
      notification_type: 'payment_rejected'
    )
  end

  def handle_undo
    contract.update_balance(-paid_amount) if paid_amount.positive?
    update!(paid_amount: nil, approved_at: nil, payment_date: nil)
  end

  def handle_approval
    record_approval_timestamp
    update_contract_balance
    notify_approval
  end
end
