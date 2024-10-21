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

  def generate_jwt
    payload = { user_id: self.id, exp: 24.hours.from_now.to_i }  # Expira en 24 horas
    JWT.encode(payload, Rails.application.secrets.secret_key_base)
  end
end
