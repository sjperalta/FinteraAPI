# frozen_string_literal: true

# app/services/authentication/authenticate_user_service.rb
module Authentication
  class AuthenticateUserService
    ACCESS_TOKEN_EXPIRY = 24.hours.from_now.to_i # Adjust based on your requirement
    REFRESH_TOKEN_EXPIRY = 30.days.from_now.to_i

    def initialize(email:, password:)
      @user = User.find_by(email:)
      @password = password
    end

    def call
      return { success: false, errors: ['Invalid email or password'] } unless @user&.valid_password?(@password)

      access_token = generate_token(exp: ACCESS_TOKEN_EXPIRY, user_id: @user.id)
      refresh_token = generate_token(exp: REFRESH_TOKEN_EXPIRY, user_id: @user.id)

      # Optionally store the refresh token securely, e.g., in a database
      {
        success: true,
        token: access_token,
        refresh_token:,
        user: @user.as_json(only: %i[id full_name email phone role confirmed_at])
      }
    end

    private

    def generate_token(payload)
      payload[:iat] = Time.now.to_i # Issued at
      JWT.encode(payload, ENV.fetch('SECRET_KEY_BASE', nil))
    end
  end
end
