# app/models/reservation_request.rb

class ReservationRequest < ApplicationRecord
  belongs_to :lot
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id' # Usuario que creó la solicitud
  has_many_attached :documents

  # Estados de la solicitud
  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected', cancelled: 'cancelled' }

  # Tipos de financiamiento
  enum financing_type: { direct: 'direct', bank: 'bank', cash: 'cash' }

  validates :lot_id, :payment_term, :financing_type, :user_id, :creator_id, presence: true
end
