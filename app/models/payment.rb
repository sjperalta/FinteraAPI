# app/models/payment.rb

class Payment < ApplicationRecord
  belongs_to :contract
  has_one_attached :document  # Archivo de comprobante de pago

  validates :amount, :due_date, :status, presence: true

  # Método para aprobar un pago
  def approve!
    self.status = 'approved'
    self.payment_date = Date.today
    #contract.update_balance(amount)
    save!
  end

  # Método para marcar un pago como vencido si no se paga a tiempo
  def mark_as_overdue!
    self.status = 'overdue'
    save!
  end
end
