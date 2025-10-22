# frozen_string_literal: true

module Users
  # Service to handle sending recovery codes to users
  class SendRecoveryCodeService
    include UserCacheInvalidation

    # Recovery code configuration
    DEVELOPMENT_CODE = '99999'
    CODE_RANGE = (10_000..99_999)
    CODE_EXPIRY_MINUTES = 15

    attr_reader :email

    def initialize(email:)
      @email = email&.downcase&.strip
    end

    def call
      return { success: false, error: I18n.t('messages.errors.email_required') } if email.blank?

      user = find_user
      return { success: false, error: I18n.t('messages.errors.email_not_found') } unless user

      code = generate_recovery_code

      update_user_with_recovery_code(user, code)
      enqueue_recovery_code_email(user, code)

      invalidate_user_cache(user)

      { success: true, message: I18n.t('messages.success.recovery_code_sent') }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to update user with recovery code: #{e.message}")
      { success: false, error: I18n.t('messages.errors.unexpected_error') }
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending recovery code: #{e.message}")
      { success: false, error: I18n.t('messages.errors.unexpected_error') }
    end

    private

    def find_user
      User.find_by(email:)
    end

    def generate_recovery_code
      if Rails.env.development?
        DEVELOPMENT_CODE
      else
        Kernel.rand(CODE_RANGE).to_s
      end
    end

    def update_user_with_recovery_code(user, code)
      user.update!(
        recovery_code: code,
        recovery_code_sent_at: Time.current
      )
    end

    def enqueue_recovery_code_email(user, code)
      SendResetCodeJob.perform_later(user.id, code)
    rescue StandardError => e
      Rails.logger.error("Failed to enqueue recovery code email for user ##{user.id}: #{e.message}")
      # Don't fail the entire operation if email enqueue fails
    end
  end
end
