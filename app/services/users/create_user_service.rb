# frozen_string_literal: true

module Users
  # Service to create a new user with notifications and proper error handling
  class CreateUserService
    attr_reader :user_params, :creator

    def initialize(user_params:, creator: nil)
      @user_params = user_params
      @creator = creator
    end

    def call
      return { success: false, errors: [I18n.t('messages.errors.user_params_required')] } if user_params.blank?

      ActiveRecord::Base.transaction do
        user = build_user
        return { success: false, errors: user.errors.full_messages } unless user.save

        # Set creator after save to ensure user has id
        user.update(created_by: creator) if creator.present?

        # Send confirmation if applicable
        send_confirmation_instructions(user)

        # Create notifications (non-blocking)
        create_notifications(user)

        { success: true, user: }
      end
    rescue ActiveRecord::RecordInvalid => e
      { success: false, errors: [e.message] }
    rescue StandardError => e
      Rails.logger.error("Unexpected error creating user: #{e.message}")
      { success: false, errors: [I18n.t('messages.errors.unexpected_user_creation_error')] }
    end

    private

    def build_user
      User.new(user_params)
    end

    def send_confirmation_instructions(user)
      user.send_confirmation_instructions if user.respond_to?(:send_confirmation_instructions)
    rescue StandardError => e
      Rails.logger.warn("Failed to send confirmation instructions: #{e.message}")
    end

    def create_notifications(user)
      notify_admin(user)
      welcome_user(user)
    rescue StandardError => e
      Rails.logger.error("Failed to create notifications: #{e.message}")
    end

    def notify_admin(user)
      User.admins.find_each do |admin|
        Notification.create!(
          user: admin,
          title: I18n.t('notifications.types.create_new_user'),
          message: I18n.t('notifications.messages.new_user_created_admin', user_name: user.full_name),
          notification_type: 'create_new_user'
        )
      end
    end

    def welcome_user(user)
      Notification.create!(
        user:,
        title: I18n.t('notifications.types.onboard_user'),
        message: I18n.t('notifications.messages.welcome_user', user_name: user.full_name),
        notification_type: 'onboard_user'
      )

      # Send welcome email
      UserMailer.welcome_email(user).deliver_later
    rescue StandardError => e
      Rails.logger.error("Failed to send welcome email: #{e.message}")
    end
  end
end
