class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable, :recoverable, :confirmable, :validatable

  # roles
  def seller?
    seller
  end

  def admin?
    admin
  end
end
