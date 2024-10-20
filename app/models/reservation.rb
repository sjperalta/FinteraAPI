# app/models/reservation.rb

class Reservation < ApplicationRecord
  belongs_to :lot
  belongs_to :creator, class_name: 'User', optional: true  # Relación con el usuario que creó la reserva
  has_many_attached :documents

  # Estados de la solicitud
  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected', cancelled: 'cancelled' }

  # Tipos de financiamiento
  enum financing_type: { direct: 'direct', bank: 'bank', cash: 'cash' }

  validates :payment_term, :financing_type, :applicant_user_id, presence: true
end
