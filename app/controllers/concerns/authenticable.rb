# frozen_string_literal: true

module Authenticable
  extend ActiveSupport::Concern

  included do
    # Generic sorting application
    def authenticate_user!
      token = request.headers['Authorization']&.split(' ')&.last
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

      decoded_token = decode_token(token)
      if decoded_token && decoded_token[:exp] > Time.now.to_i
        @current_user = User.find(decoded_token[:user_id])
      else
        render json: { error: 'Token expired or invalid' }, status: :unauthorized
      end
    end

    def decode_token(token)
      JWT.decode(token, ENV.fetch('SECRET_KEY_BASE', nil), true, { algorithm: 'HS256' })[0].symbolize_keys
    rescue JWT::DecodeError
      nil
    end

    def generate_token(payload)
      payload[:iat] = Time.now.to_i
      JWT.encode(payload, ENV.fetch('SECRET_KEY_BASE', nil))
    end
  end
end
