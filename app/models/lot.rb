# app/models/lot.rb

class Lot < ApplicationRecord
  belongs_to :project  # Relación con el proyecto al que pertenece el lote
  has_many :contracts, dependent: :destroy  # Relación con las reservas. Se eliminarán si el lote es eliminado.

  before_save :calculate_price

  # Validaciones
  validates :name, presence: true
  validates :length, :width, numericality: { greater_than: 0 }, presence: true

  private

  # Método para calcular el área del lote
  def area
    length * width
  end

  def calculate_price
    self.price = area * project.price_per_square_foot
  end
end
