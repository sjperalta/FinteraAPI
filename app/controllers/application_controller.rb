# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit
  # Optionally, set the controller_info for additional metadata
  before_action :set_paper_trail_custom_attributes

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

  def user_for_paper_trail
    current_user&.id
  end

  def decode_token(token)
    JWT.decode(token, ENV['SECRET_KEY_BASE'], true, { algorithm: 'HS256' })[0].symbolize_keys
  rescue JWT::DecodeError
    nil
  end

  def generate_token(payload)
    payload[:iat] = Time.now.to_i
    JWT.encode(payload, ENV['SECRET_KEY_BASE'])
  end

  def set_paper_trail_custom_attributes
    if defined?(PaperTrail) && current_user
      PaperTrail.request.controller_info = {
        ip: request.remote_ip,
        user_agent: request.user_agent
      }
    end
  end
end
