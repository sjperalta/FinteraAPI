class User < ApplicationRecord
  #has_secure_password
  # Devise modules
  devise :database_authenticatable, :registerable, :recoverable, :confirmable, :validatable

  # PaperTrail for versioning
  has_paper_trail

  has_many :contracts, foreign_key: :applicant_user_id, dependent: :destroy
  has_many :payments, through: :contracts
  has_many :audits, dependent: :destroy
  has_many :notifications, foreign_key: :user_id, dependent: :destroy

  validates :full_name, presence: true
  validates :phone, presence: true
  validates :identity, presence: true, uniqueness: true
  validates :rtn, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  enum :status, { active: 'active', inactive: 'inactive', suspended: 'suspended' }

  # Definir los roles permitidos
  ROLES = %w[user admin seller].freeze

  validates :role, inclusion: { in: ROLES }

  # Callbacks for Normalization (Optional)
  before_validation :normalize_identity_and_rtn

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
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end

   # Método para verificar si el usuario está activo
  def active_for_authentication?
    super && active?
  end

  # Mensaje de error cuando el usuario está inactivo
  def inactive_message
    !active? ? :inactive : super
  end

  def can_resend_confirmation_email?
    !confirmed? && confirmation_token.present?
  end

  private

  def normalize_identity_and_rtn
    self.identity = identity.strip if identity.present?
    self.rtn = rtn.strip if rtn.present?
  end
end
