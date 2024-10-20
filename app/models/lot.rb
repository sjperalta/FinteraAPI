# app/models/lot.rb

class Lot < ApplicationRecord
  belongs_to :project

  before_save :calculate_price

  validates :name, :length, :width, presence: true

  private

  def calculate_price
    self.price = self.length * self.width * self.project.price_per_square_foot
  end
end
