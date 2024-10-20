# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  before_action :authenticate_user!
  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: 'No tienes acceso a esta sección' }, status: :forbidden
  end

  private

  def authenticate_user!
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    service = Authentication::DecodeTokenService.new(token: token)
    result = service.call

    if result[:success]
      @current_user = result[:user]
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
