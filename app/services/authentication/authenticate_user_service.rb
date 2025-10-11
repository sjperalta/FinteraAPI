# frozen_string_literal: true

# app/services/authentication/authenticate_user_service.rb
module Authentication
  # Service to authenticate a user and generate JWT tokens
  class AuthenticateUserService
    # Use durations and compute concrete expiry timestamps at runtime so tests
    # and long-running processes don't observe stale timestamps.
    ACCESS_TOKEN_EXPIRATION_SECONDS = 24.hours.to_i
    REFRESH_TOKEN_EXPIRATION_SECONDS = 30.days.to_i

    def initialize(email:, password:)
      # normalize email: strip whitespace for case-insensitive lookup (SQL handles case)
      normalized_email = email.to_s.strip
      # Use a SQL lower(...) comparison to ensure case-insensitive lookup regardless of DB collation
      @user = User.where('LOWER(email) = ?', normalized_email).first
      @password = password
    end

    def call
      # deny authentication when user not found or password invalid
      return { success: false, errors: [I18n.t('auth.invalid_credentials')] } unless @user&.valid_password?(@password)

      # prevent inactive users from signing in
      if @user.respond_to?(:active?) && !@user.active?
        return { success: false, errors: [I18n.t('auth.account_inactive')] }
      end

      # Compute fresh expiry timestamps
      access_exp = Time.now.to_i + ACCESS_TOKEN_EXPIRATION_SECONDS
      refresh_expires_at = Time.current + REFRESH_TOKEN_EXPIRATION_SECONDS.seconds

      access_token = generate_token(exp: access_exp, user_id: @user.id)

      # Create a DB-backed refresh token (rotate-friendly). Use a random value rather than a JWT so we can revoke/rotate easily.
      refresh_token_value = SecureRandom.hex(64)

      begin
        RefreshToken.transaction do
          RefreshToken.create!(user: @user, token: refresh_token_value, expires_at: refresh_expires_at)
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create refresh token for user=#{@user.id}: #{e.message}"
        return { success: false, errors: [I18n.t('auth.invalid_credentials')] }
      end

      {
        success: true,
        token: access_token,
        refresh_token: refresh_token_value,
        user: @user.as_json(only: %i[id full_name identity rtn email phone role address confirmed_at locale])
      }
    end

    private

    def generate_token(payload)
      payload[:iat] = Time.now.to_i # Issued at
      JWT.encode(payload, ENV.fetch('SECRET_KEY_BASE', nil))
    end
  end
end
