# app/models/lot.rb

class Lot < ApplicationRecord
  has_paper_trail

  belongs_to :project  # Relación con el proyecto al que pertenece el lote
  has_many :contracts, dependent: :destroy  # Relación con las reservas. Se eliminarán si el lote es eliminado.

  before_save :calculate_price

  # Validaciones
  validates :name, presence: true
  validates :length, :width, numericality: { greater_than: 0 }, presence: true

  #has_one :current_contract, -> { order(created_at: :desc) }, class_name: 'Contract'
  has_one :current_contract, -> { where(active: true) }, class_name: 'Contract'
  #delegate :applicant_user, to: :current_contract, allow_nil: true

  # Método para calcular el área del lote
  def area_m2
    length * width
  end

  def area_square_feet
    area_m2 * 10.7639  # 1 m² = 10.7639 ft²
  end

  def area_square_vara
    area_m2 * 1.431  # 1 metro cuadrado = 1.431 varas cuadradas
  end

  private

  def calculate_price
    self.price = area_square_vara * project.price_per_square_vara
  end
end
