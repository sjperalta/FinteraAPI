# frozen_string_literal: true

module Notifiable
  extend ActiveSupport::Concern

  private

  def create_notification(user:, title:, message:, notification_type:)
    return unless user

    Notification.create!(
      user:,
      title:,
      message:,
      notification_type:
    )
  rescue StandardError => e
    Rails.logger.error "Failed to create notification: #{e.message}"
  end

  def notify_admins(title:, message:, notification_type:)
    User.where(role: 'admin').find_each do |admin|
      create_notification(
        user: admin,
        title:,
        message:,
        notification_type:
      )
    end
  end

  def notify_user_and_admins(user:, title:, message:, notification_type:)
    create_notification(
      user:,
      title:,
      message:,
      notification_type:
    )

    notify_admins(
      title:,
      message:,
      notification_type:
    )
  end
end
