# app/models/contract.rb

class Contract < ApplicationRecord
  has_paper_trail

  belongs_to :lot
  belongs_to :creator, foreign_key: :creator_id, class_name: 'User', optional: true
  #belongs_to :applicant_user, foreign_key: :applicant_user_id, class_name: 'User', optional: true
  belongs_to :applicant_user, class_name: 'User', foreign_key: 'applicant_user_id', optional: true
  has_many_attached :documents
  has_many :payments, dependent: :destroy  # Relación con los pagos
  before_create :set_amounts

  validates :payment_term, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :financing_type, presence: true, inclusion: { in: %w[direct bank cash] }
  validates :reserve_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :acceptable_documents

  scope :active, -> { where(active: true) }

  STATUS_APPROVED = "approved"

  def set_amounts
    self.amount = self.lot.price
    self.balance = self.amount
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
    project_name = self.lot&.project&.name

    # Crea el pago de la reserva y la prima
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Reserva", due_date: Date.today, amount: reserve_amount, status: 'pending', payment_type: 'reservation')
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Prima", due_date: Date.today.next_month, amount: down_payment, status: 'pending', payment_type: 'down_payment')

    # Crea los pagos restantes
    remaining_balance = amount - reserve_amount - down_payment
    monthly_payment = remaining_balance / payment_term

    payment_term.times do |i|
      due_date = (Date.today + (i + 2).months)
      Payment.create!(
        contract: self,
        due_date: due_date,
        description: "Proyecto #{project_name} - Cuota #{i + 1}",
        amount: monthly_payment,
        status: 'pending',
        payment_type: 'installment',
      )
    end
  end

  # Crear un único pago para financiamiento bancario o contado
  def create_single_payment
    project_name = self.lot&.project&.name
    remaining_balance = amount - reserve_amount
    # Crea el pago de la reserva y el pago completo.
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Reserva", due_date: Date.today, amount: reserve_amount, status: 'pending', payment_type: 'reservation')
    Payment.create!(contract: self, description: "Proyecto #{project_name} - Contado", due_date: Date.today.next_month, amount: remaining_balance, status: 'pending', payment_type: 'installment')
  end

  def acceptable_documents
    return unless documents.attached?

    documents.each do |document|
      unless document.byte_size <= 10.megabytes
        errors.add(:documents, "is too big")
      end

      acceptable_types = ["application/pdf", "image/jpeg", "image/png"]
      unless acceptable_types.include?(document.content_type)
        errors.add(:documents, "must be a PDF, JPG, or PNG")
      end
    end
  end
end
