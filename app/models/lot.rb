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
  validates :length, :width, numericality: { greater_than: 0 }, presence: true, unless: -> { override_area.present? }
  validates :override_area, numericality: { greater_than: 0 }, allow_nil: true

  # the active contract and last from the contracts
  has_one :current_contract, -> { where(active: true).order(created_at: :desc) }, class_name: 'Contract'

  def area_m2
    override_area.presence || (length * width)
  end

  def area_in_project_unit
    MeasurementUnits.convert_area(area_m2, measurement_unit || project&.measurement_unit)
  end

  def effective_price
    return override_price if override_price.present?
    return project.price_per_square_unit * override_area if override_area.present?

    price
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

    return if override_price.present?

    # Don't override the price field, keep the original calculated price
    # The override_price field will be used for display/billing purposes

    # Only calculate and set price if no override is present
    base_area = area_m2.to_d
    self.price = base_area * project.price_per_square_unit.to_d
  end
end
