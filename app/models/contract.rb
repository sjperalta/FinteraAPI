# frozen_string_literal: true

# app/models/contract.rb

class Contract < ApplicationRecord
  include Notifiable
  include AASM
  has_paper_trail

  belongs_to :lot
  belongs_to :creator, foreign_key: :creator_id, class_name: 'User', optional: true
  # belongs_to :applicant_user, foreign_key: :applicant_user_id, class_name: 'User', optional: true
  belongs_to :applicant_user, class_name: 'User', foreign_key: 'applicant_user_id', optional: true
  has_many_attached :documents
  has_many :payments, dependent: :destroy # Relación con los pagos
  before_create :set_amounts

  validates :payment_term, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :financing_type, presence: true, inclusion: { in: %w[direct bank cash] }
  validates :reserve_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :acceptable_documents

  scope :active_contracts, -> { where(active: true) }
  scope :approved_between, ->(start_date, end_date) { where(status: 'approved', approved_at: start_date..end_date) }
  scope :with_creator_and_lot, -> { includes(:creator, :lot) }
  scope :pending_approval, -> { where(status: %w[pending submitted]) }
  scope :by_financing_type, ->(type) { where(financing_type: type) }
  scope :by_applicant_user, ->(user_id) { where(applicant_user_id: user_id) }

  STATUS_APPROVED = 'approved'

  # State Machine Definition
  aasm column: :status do
    state :pending, initial: true
    state :submitted
    state :approved
    state :rejected
    state :cancelled

    # Submit contract
    event :submit do
      transitions from: %i[pending rejected], to: :submitted,
                  guard: :valid_for_submission?
    end

    # Approve contract
    event :approve do
      transitions from: %i[pending submitted rejected], to: :approved,
                  guard: :can_be_approved?,
                  after: %i[record_approval create_payments notify_approval]
    end

    # Reject contract
    event :reject do
      transitions from: %i[pending submitted], to: :rejected,
                  after: :notify_rejection
    end

    # Cancel contract
    event :cancel do
      transitions from: [:rejected], to: :cancelled,
                  after: %i[release_lot delete_payments notify_cancellation]
    end
  end

  def calculate_financing_amount
    amount - (reserve_amount + down_payment)
  end

  def set_amounts
    self.amount = lot.price
    self.balance = amount
  end

  # Método para actualizar el saldo pendiente
  def update_balance(payment_amount)
    self.balance -= payment_amount
    save!
  end

  # Método para crear pagos según el tipo de financiamiento
  def create_payments
    case financing_type
    when 'direct'
      create_direct_payments
    when 'bank', 'cash'
      create_single_payment
    else
      raise "Tipo de financiamiento desconocido: #{financing_type}"
    end
  end

  private

  # Crear pagos para el tipo de financiamiento directo
  def create_direct_payments
    project_name = lot&.project&.name

    # Crea el pago de la reserva y la prima
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Reserva", due_date: Date.today,
                    amount: reserve_amount, status: 'pending', payment_type: 'reservation')
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Prima", due_date: Date.today.next_month,
                    amount: down_payment, status: 'pending', payment_type: 'down_payment')

    # Crea los pagos restantes
    remaining_balance = amount - reserve_amount - down_payment
    monthly_payment = remaining_balance / payment_term

    payment_term.times do |i|
      due_date = (Date.today + (i + 2).months)
      Payment.create!(
        contract: self,
        due_date:,
        description: "Proyecto #{project_name} - Cuota #{i + 1}",
        amount: monthly_payment,
        status: 'pending',
        payment_type: 'installment'
      )
    end
  end

  # Crear un único pago para financiamiento bancario o contado
  def create_single_payment
    project_name = lot&.project&.name
    remaining_balance = amount - reserve_amount
    # Crea el pago de la reserva y el pago completo.
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Reserva", due_date: Date.today,
                    amount: reserve_amount, status: 'pending', payment_type: 'reservation')
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Contado", due_date: Date.today.next_month,
                    amount: remaining_balance, status: 'pending', payment_type: 'installment')
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
    valid_for_submission? && (status == 'pending' || status == 'submitted')
  end

  def can_be_rejected?
    status == 'approved'
  end

  def record_approval
    update!(
      approved_at: Time.current,
      active: true
    )
  end

  def notify_approval
    create_notification(
      user: applicant_user,
      title: 'Contrato Aprobado',
      message: "Tu contrato para #{lot.name} ha sido aprobado",
      notification_type: 'contract_approved'
    )

    notify_admins(
      title: 'Contrato Aprobado',
      message: "Contrato ##{id} para #{lot.name} ha sido aprobado.",
      notification_type: 'contract_approved'
    )
  end

  def notify_rejection
    create_notification(
      user: applicant_user,
      title: 'Contrato Rechazado',
      message: "Tu contrato para #{lot.name} ha sido rechazado, detalle: #{rejection_reason}",
      notification_type: 'contract_rejected'
    )
  end

  def notify_cancellation
    create_notification(
      user: applicant_user,
      title: 'Contrato Cancelado',
      message: "Tu contrato para #{lot.name} ha sido cancelado, lote se liberado.",
      notification_type: 'contract_cancelled'
    )

    notify_admins(
      title: 'Contrato Cancelado',
      message: "El contrato #{lot.name} ha sido cancelado, lote se liberado.",
      notification_type: 'contract_cancelled'
    )
  end

  def release_lot
    update!(active: false)
    lot.update!(status: 'available')
  end

  def delete_payments
    payments.destroy_all
  end
end
