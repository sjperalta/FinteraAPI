# app/models/contract.rb

class Contract < ApplicationRecord
  belongs_to :lot
  belongs_to :creator, class_name: 'User', optional: true
  has_many_attached :documents
  has_many :payments, dependent: :destroy  # Relación con los pagos
  before_create :set_balance

  validates :payment_term, :financing_type, :applicant_user_id, :down_payment, :reserve_amount, presence: true
  validates :financing_type, inclusion: { in: %w(direct bank cash) }

  def set_balance
    self.balance = self.lot.price
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
    end
  end

  private

  # Crear pagos para el tipo de financiamiento directo
  def create_direct_payments
    # Crea el pago de la reserva y la prima
    Payment.create!(contract: self, due_date: Date.today, amount: contract_amount, status: 'pending')
    Payment.create!(contract: self, due_date: Date.today, amount: down_payment, status: 'pending')

    # Crea los pagos restantes
    remaining_balance = lot.price - contract_amount - down_payment
    monthly_payment = remaining_balance / payment_term

    payment_term.times do |month|
      Payment.create!(
        contract: self,
        due_date: Date.today + (month + 1).months,
        amount: monthly_payment,
        status: 'pending'
      )
    end
  end

  # Crear un único pago para financiamiento bancario o contado
  def create_single_payment
    Payment.create!(contract: self, due_date: Date.today, amount: lot.price, status: 'pending')
  end
end
