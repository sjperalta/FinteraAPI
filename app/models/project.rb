# frozen_string_literal: true

# app/models/project.rb
# Model representing a real estate project, including pricing and measurement units.
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

  scope :by_project_type, ->(type) { where(project_type: type) }
  scope :by_price_range, ->(min, max) { where(price_per_square_unit: min..max) }
  scope :by_interest_rate, ->(rate) { where(interest_rate: rate) }

  # Callbacks
  before_create :generate_guid
  before_create :initialize_lot_count
  after_save_commit :total_lot_value

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
    self.guid ||= SecureRandom.uuid
  end

  def initialize_lot_count
    self.lot_count ||= 0
  end
end
