# app/models/lot.rb

class Lot < ApplicationRecord
  has_paper_trail

  belongs_to :project
  has_many :contracts, dependent: :destroy

  before_validation :inherit_measurement_unit, if: -> { project.present? && measurement_unit.blank? }
  before_save :calculate_price

  validates :name, presence: true
  validates :length, :width, numericality: { greater_than: 0 }, presence: true

  has_one :current_contract, -> { where(active: true) }, class_name: 'Contract'

  def area_m2
    length * width
  end

  def area_in_project_unit
    MeasurementUnits.convert_area(area_m2, measurement_unit || project&.measurement_unit)
  end

  private

  def inherit_measurement_unit
    self.measurement_unit = project.measurement_unit
  end

  def calculate_price
    self.price = project.price_for(area_m2) if project
  end
end
