# app/controllers/api/v1/authentication_controller.rb

class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :refresh, :logout]

  # POST /api/v1/auth/login
  def login
    service = Authentication::AuthenticateUserService.new(email: params[:email], password: params[:password])
    result = service.call

    if result[:success]
      render json: { token: result[:token], refresh_token: result[:refresh_token], user: result[:user] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: 401
    end
  end

  # POST /api/v1/auth/logout
  def logout
    # Example if using a database to store refresh tokens
    refresh_token = params[:refresh_token]
    current_user.refresh_tokens.find_by(token: refresh_token)&.destroy
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  # POST /api/v1/auth/refresh
  def refresh
    refresh_token = params[:refresh_token]
    decoded_token = decode_token(refresh_token)

    if decoded_token && decoded_token[:exp] > Time.now.to_i
      user = User.find(decoded_token[:user_id])
      new_access_token = generate_token(exp: 24.hours.from_now.to_i, user_id: user.id)

      render json: { token: new_access_token, user: user }, status: :ok
    else
      render json: { errors: ['Invalid or expired refresh token'] }, status: 401
    end
  rescue JWT::DecodeError
    render json: { errors: ['Invalid token'] }, status: 401
  end

  private

  def decode_token(token)
    JWT.decode(token, Rails.application.secrets.secret_key_base)[0].symbolize_keys
  rescue JWT::DecodeError
    nil
  end

  def generate_token(payload)
    payload[:iat] = Time.now.to_i
    JWT.encode(payload, Rails.application.secrets.secret_key_base)
  end
end
