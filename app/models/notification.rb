# frozen_string_literal: true

# app/models/notification.rb
# Model representing a notification sent to users.
class Notification < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  # Validations
  validates :message, presence: true
  validates :user_id, presence: true

  # Optional: If you define a list of valid notification types
  # NOTIFICATION_TYPES = %w[contract_approved payment_due general].freeze
  # validates :notification_type, inclusion: { in: NOTIFICATION_TYPES }, allow_nil: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Mark a single notification as read
  def mark_as_read!
    return true if read?

    update!(read_at: Time.current)
  end

  # Check if the notification is read
  def read?
    read_at.present?
  end

  # Get notification type from notifiable
  def notification_type
    self[:notification_type]&.demodulize&.underscore || 'general'
  end
end
