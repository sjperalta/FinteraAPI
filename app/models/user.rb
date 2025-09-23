# frozen_string_literal: true

# app/models/user.rb
# Model representing a user in the system, including authentication and role management.
class User < ApplicationRecord
  # has_secure_password
  # Devise modules
  include Discard::Model
  devise :database_authenticatable, :registerable, :recoverable, :confirmable, :validatable

  # PaperTrail for versioning
  has_paper_trail

  has_many :contracts, foreign_key: :applicant_user_id, dependent: :destroy
  has_many :payments, through: :contracts
  has_many :audits, dependent: :destroy
  has_many :notifications, foreign_key: :user_id, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy
  belongs_to :creator, class_name: 'User', foreign_key: :created_by, optional: true

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

  # Ensure soft-deleted records are excluded by default
  # default_scope { where(discarded_at: nil) }
  default_scope -> { kept }

  # Verificar si el usuario es administrador
  def admin?
    role == 'admin'
  end

  # Verificar si el usuario es vendedor
  def seller?
    role == 'seller'
  end

  def generate_jwt
    payload = { user_id: id, exp: 24.hours.from_now.to_i } # Expira en 24 horas
    JWT.encode(payload, ENV.fetch('SECRET_KEY_BASE', nil))
  end

  # Método para verificar si el usuario está activo
  def active_for_authentication?
    super && active? && !discarded?
  end

  # Mensaje de error cuando el usuario está inactivo
  def inactive_message
    active? ? super : :inactive
  end

  def can_resend_confirmation_email?
    !confirmed? && confirmation_token.present?
  end

  def soft_delete
    discard! # Marks user as discarded (soft delete)
  end

  def restore
    undiscard! # Restores soft-deleted user
  end

  private

  def normalize_identity_and_rtn
    self.identity = identity.strip if identity.present?
    self.rtn = rtn.strip if rtn.present?
  end
end
