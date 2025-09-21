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
    case measurement_unit || project&.measurement_unit
    when 'm2'
      area_m2
    when 'ft2'
      area_m2 * 10.7639
    when 'vara2'
      area_m2 * 1.431
    else
      area_m2
    end
  end

  private

  def inherit_measurement_unit
    self.measurement_unit = project.measurement_unit
  end

  def calculate_price
    self.price = project.price_for(area_m2) if project
  end
end
