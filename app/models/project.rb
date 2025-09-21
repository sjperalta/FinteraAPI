# app/models/project.rb

class Project < ApplicationRecord
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
    case measurement_unit
    when 'm2'
      area_in_m2 * price_per_square_unit
    when 'ft2'
      # Convert m2 to ft2 then multiply
      (area_in_m2 * 10.7639) * price_per_square_unit
    when 'vara2'
      # Convert m2 to vara2 (1 m2 = 1.431 vara2)
      (area_in_m2 * 1.431) * price_per_square_unit
    else
      area_in_m2 * price_per_square_unit
    end
  end

  private

  def total_lot_value
    lots.sum(&:price)
  end

  def generate_guid
    self.guid = SecureRandom.uuid
  end
end
