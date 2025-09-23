# frozen_string_literal: true

# app/models/lot.rb
# Model representing a lot within a project, including area and price calculations.
class Lot < ApplicationRecord
  has_paper_trail

  belongs_to :project, counter_cache: :lot_count
  has_many :contracts, dependent: :destroy

  before_validation :inherit_measurement_unit, if: -> { project.present? && measurement_unit.blank? }
  before_save :calculate_price
  after_initialize :set_defaults

  LOT_STATUS = %w[available reserved sold].freeze

  validates :status, inclusion: { in: LOT_STATUS }
  validates :name, presence: true
  validates :length, :width, numericality: { greater_than: 0 }, presence: true

  has_one :current_contract, -> { where(active: true) }, class_name: 'Contract'

  def area_m2
    length * width
  end

  def area_in_project_unit
    MeasurementUnits.convert_area(area_m2, measurement_unit || project&.measurement_unit)
  end

  # Method to get the effective price (override if present, otherwise calculated)
  def effective_price
    override_price.present? ? override_price : price
  end

  private

  def set_defaults
    self.status ||= 'available'
  end

  def inherit_measurement_unit
    self.measurement_unit = project.measurement_unit
  end

  def calculate_price
    return unless project

    if override_price.present?
      # Don't override the price field, keep the original calculated price
      # The override_price field will be used for display/billing purposes
      return
    else
      # Only calculate and set price if no override is present
      base_area = length.to_d * width.to_d
      self.price = base_area * project.price_per_square_unit.to_d
    end
  end
end
