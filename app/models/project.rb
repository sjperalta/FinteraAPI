# app/models/project.rb

class Project < ApplicationRecord
  has_many :lots, dependent: :destroy

  validates :name, :description, :address, :lot_count, :price_per_square_foot, :interest_rate, presence: true
  before_create :generate_guid

  private

  def generate_guid
    self.guid = SecureRandom.uuid
  end
end
