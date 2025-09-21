# app/models/project.rb

class Project < ApplicationRecord
  include MeasurementUnits
  has_paper_trail
  has_many :lots, dependent: :destroy

  MEASUREMENT_UNITS = %w[m2 ft2 vara2].freeze

  validates :name, :description, :address, presence: true
  validates :price_per_square_unit, :interest_rate, numericality: { greater_than: 0 }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, presence: true
  validates :measurement_unit, inclusion: { in: MEASUREMENT_UNITS }

  before_create :generate_guid

  def price_for(area_in_m2)
    # Normalize area to the unit configured
    normalized_area = MeasurementUnits.convert_area(area_in_m2, measurement_unit)
    normalized_area * price_per_square_unit
  end

  private

  def total_lot_value
    lots.sum(&:price)
  end

  def generate_guid
    self.guid = SecureRandom.uuid
  end
end
