class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable, :recoverable, :confirmable, :validatable

  # Definir los roles permitidos
  ROLES = %w[user admin seller].freeze

  validates :role, inclusion: { in: ROLES }

  # Verificar si el usuario es administrador
  def admin?
    role == 'admin'
  end

  # Verificar si el usuario es vendedor
  def seller?
    role == 'seller'
  end
end
