# frozen_string_literal: true

# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  include Pagy::Backend
  include Authenticable

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit
  before_action :set_paper_trail_custom_attributes
  before_action :set_sentry_user

  rescue_from CanCan::AccessDenied do |_exception|
    render json: { error: 'No tienes acceso a esta sección' }, status: :forbidden
  end

  private

  attr_reader :current_user

  def user_for_paper_trail
    current_user&.id
  end

  def set_paper_trail_custom_attributes
    return unless defined?(PaperTrail) && current_user

    PaperTrail.request.controller_info = {
      ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  # Set Sentry user context so errors include the logged in user
  def set_sentry_user
    return unless defined?(Sentry) && current_user

    Sentry.set_user(
      id: current_user.id,
      email: current_user.email,
      username: current_user.full_name
    )

    Sentry.set_extras(
      ip: request.remote_ip,
      params: request.filtered_parameters.except('controller', 'action')
    )
  end
end
