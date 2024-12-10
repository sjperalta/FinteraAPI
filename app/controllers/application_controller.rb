# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  before_action :authenticate_user!
  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: 'No tienes acceso a esta sección' }, status: :forbidden
  end

  private

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

  def current_user
    @current_user
  end

  def decode_token(token)
    JWT.decode(token, Rails.application.secrets.secret_key_base)[0].symbolize_keys
  rescue JWT::DecodeError
    nil
  end
end
