# app/controllers/api/v1/authentication_controller.rb

class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :refresh]

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
    refresh_token = params[:refresh_token]

    if refresh_token.blank?
      return render json: { error: 'Invalid or missing token' }, status: 401
    end

    # Find refresh token
    token = RefreshToken.find_by(token: refresh_token)

    if token
      token.destroy
      render json: { message: 'Logged out successfully' }, status: :ok
    else
      render json: { error: 'Invalid or missing token' }, status: 401
    end
  end

  # POST /api/v1/auth/refresh
  def refresh
    refresh_token = params[:refresh_token]
    decoded_token = decode_token(refresh_token)

    if decoded_token && decoded_token[:exp] > Time.now.to_i
      user = User.find(decoded_token[:user_id])
      new_access_token = generate_token(exp: 24.hours.from_now.to_i, user_id: user.id)

      render json: { token: new_access_token, user: user.as_json(only: [:id, :full_name, :identity, :rtn, :email, :phone, :role, :status]) }, status: :ok
    else
      render json: { errors: ['Invalid or expired refresh token'] }, status: 401
    end
  rescue JWT::DecodeError
    render json: { errors: ['Invalid token'] }, status: 401
  end

  private

  def decode_token(token)
    JWT.decode(token, ENV['SECRET_KEY_BASE'])[0].symbolize_keys
  rescue JWT::DecodeError
    nil
  end

  def generate_token(payload)
    payload[:iat] = Time.now.to_i
    JWT.encode(payload, ENV['SECRET_KEY_BASE'])
  end
end
