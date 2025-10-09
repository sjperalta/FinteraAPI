# frozen_string_literal: true

# app/services/authentication/authenticate_user_service.rb
module Authentication
  # Service to authenticate a user and generate JWT tokens
  class AuthenticateUserService
    ACCESS_TOKEN_EXPIRY = 24.hours.from_now.to_i # Adjust based on your requirement
    REFRESH_TOKEN_EXPIRY = 30.days.from_now.to_i

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

      access_token = generate_token(exp: ACCESS_TOKEN_EXPIRY, user_id: @user.id)
      refresh_token = generate_token(exp: REFRESH_TOKEN_EXPIRY, user_id: @user.id)

      # Optionally store the refresh token securely, e.g., in a database
      {
        success: true,
        token: access_token,
        refresh_token:,
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
