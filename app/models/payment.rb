# app/models/payment.rb
class Payment < ApplicationRecord
  include AASM

  belongs_to :contract
  has_one_attached :document

  validates :amount, :due_date, :status, presence: true

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
    event :approve do
      transitions from: :submitted, to: :paid,
                  guard: :can_be_approved?,
                  after: [:record_approval_timestamp, :update_contract_balance, :notify_approval]
    end

    # Transition from submitted to rejected when payment is rejected
    event :reject do
      transitions from: :submitted, to: :rejected,
                  after: :notify_rejection
    end
  end

  def document_url
    return unless document.attached?
    Rails.application.routes.url_helpers.url_for(document)
  end

  private

  def document_attached?
    document.attached?
  end

  def can_be_approved?
    document_attached? && contract.present?
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
    Notification.create!(
      user: contract.applicant_user,
      title: "Actualización Pago",
      message: "Pago ##{id} a sido enviado para aprobación.",
      notification_type: 'payment_submitted'
    )
  end

  def notify_approval
    Notification.create!(
      user: contract.applicant_user,
      title: "Actualización Pago",
      message: "Pago ##{id} ha sido aprobado, monto: #{paid_amount}.",
      notification_type: 'payment_approved'
    )

    # Notify admins
    User.where(role: 'admin').each do |admin|
      Notification.create!(
        user: admin,
        title: "Actualización Pago",
        message: "Pago ##{id} ha sido aprobado, monto: #{paid_amount}.",
        notification_type: 'payment_approved'
      )
    end
  end

  def notify_rejection
    Notification.create!(
      user: contract.applicant_user,
      title: "Actualización Pago",
      message: "Pago ##{id} ha sido rechazado.",
      notification_type: 'payment_rejected'
    )
  end
end
