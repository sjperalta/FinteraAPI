# frozen_string_literal: true

module Users
  # Service to create a new user with notifications and proper error handling
  class CreateUserService
    include UserCacheInvalidation

    attr_reader :user_params, :creator

    def initialize(user_params:, creator: nil)
      @user_params = user_params
      @creator = creator
    end

    def call
      return { success: false, errors: [I18n.t('messages.errors.user_params_required')] } if user_params.blank?

      user_for_email = nil

      ActiveRecord::Base.transaction do
        user = build_user
        return { success: false, errors: user.errors.full_messages } unless user.save

        # Set creator after save to ensure user has id
        user.update(created_by: creator) if creator.present?
        user.skip_confirmation!

        create_notifications(user)

        invalidate_user_cache(user)

        # Capture user and password for email scheduling after commit
        user_for_email = user if user.persisted?
      end

      # Send confirmation if applicable
      schedule_account_created_email(user_for_email)
      { success: true, user: user_for_email }
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

    def schedule_account_created_email(user)
      UserMailer.with(user:).account_created.deliver_later
    rescue StandardError => e
      Rails.logger.error("Failed to enqueue account_created email for user ##{user.id}: #{e.message}")
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
