# frozen_string_literal: true

# app/models/notification.rb

class Notification < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :message, presence: true
  validates :user_id, presence: true

  # Optional: If you define a list of valid notification types
  # NOTIFICATION_TYPES = %w[contract_approved payment_due general].freeze
  # validates :notification_type, inclusion: { in: NOTIFICATION_TYPES }, allow_nil: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }

  # Mark a single notification as read
  def mark_as_read!
    update!(read_at: Time.current) if read_at.nil?
  end

  # Check if the notification is read
  def read?
    read_at.present?
  end
end
