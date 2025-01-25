# app/models/payment.rb

class Payment < ApplicationRecord
  belongs_to :contract
  has_one_attached :document  # Archivo de comprobante de pago

  validates :amount, :due_date, :status, presence: true

  # Método para aprobar un pago
  def approve!
    self.status = 'paid'
    self.approved_at = Time.current
    self.payment_date = Date.today
    self.paid_amount = self.amount
    save!
  end

  def pending?
    self.status == 'pending'
  end

  def submitted?
    self.status == 'submitted'
  end
end
