# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  include Pagy::Backend
  include Authenticable

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit
  # Optionally, set the controller_info for additional metadata
  before_action :set_paper_trail_custom_attributes

  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: 'No tienes acceso a esta sección' }, status: :forbidden
  end

  private

  def current_user
    @current_user
  end

  def user_for_paper_trail
    current_user&.id
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
