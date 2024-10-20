# app/models/project.rb

class Project < ApplicationRecord
  has_many :lots, dependent: :destroy

  # Validaciones
  validates :name, :description, :address, presence: true
  validates :price_per_square_foot, :interest_rate, numericality: { greater_than: 0 }
  before_create :generate_guid

  private

  # Método para calcular el precio total de todos los lotes
  def total_lot_value
    lots.sum(&:price)
  end

  def generate_guid
    self.guid = SecureRandom.uuid
  end
end
