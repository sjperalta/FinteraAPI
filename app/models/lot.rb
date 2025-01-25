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

  private

  # Método para calcular el área del lote
  def area
    length * width
  end

  def calculate_price
    self.price = area * project.price_per_square_foot
  end
end
