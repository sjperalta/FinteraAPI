# frozen_string_literal: true

# app/services/authentication/refresh_token_service.rb
module Authentication
  # Service to handle refresh token validation and rotation
  class RefreshTokenService
    def initialize(refresh_token:)
      @provided_token = refresh_token
    end

    def call
      return { success: false, errors: [I18n.t('auth.invalid_refresh_token')] } if @provided_token.blank?

      token_record = RefreshToken.find_by(token: @provided_token)
      return { success: false, errors: [I18n.t('auth.invalid_refresh_token')] } if token_record.nil?

      if token_record.expires_at < Time.current
        token_record.destroy
        return { success: false, errors: [I18n.t('auth.refresh_token_expired')] }
      end

      user = token_record.user

      # Rotate refresh token
      new_refresh_token = SecureRandom.hex(64)
      new_expires_at = 30.days.from_now

      RefreshToken.transaction do
        token_record.destroy!
        RefreshToken.create!(user:, token: new_refresh_token, expires_at: new_expires_at)
      end

      new_access_token = generate_token(exp: 24.hours.from_now.to_i, user_id: user.id)

      {
        success: true,
        token: new_access_token,
        refresh_token: new_refresh_token,
        user: user.as_json(only: %i[id full_name address identity rtn email phone role status locale])
      }
    rescue ActiveRecord::RecordInvalid => _e
      { success: false, errors: [I18n.t('auth.refresh_rotation_failed')] }
    end

    private

    def generate_token(payload)
      payload[:iat] = Time.now.to_i
      JWT.encode(payload, ENV.fetch('SECRET_KEY_BASE', nil))
    end
  end
end
