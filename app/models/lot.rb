# frozen_string_literal: true

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
    return unless project

    if override_price.present?
      self.price = override_price
    else
      # Formula: length * width * project.price_per_square_unit
      # Using to_d to ensure decimal precision
      base_area = length.to_d * width.to_d
      self.price = base_area * project.price_per_square_unit.to_d
    end
  end
end
