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

  protected

  # def parse_sort_param(sort_param)
  #   field, direction = sort_param.split('-')
  #   direction = direction.downcase == 'desc' ? 'desc' : 'asc'
  #   [field, direction]
  # end

  # def apply_filters(scope, params, searchable_fields)
  #   model = scope.model.table_name

  #   # Apply status filter
  #   scope = scope.where(status: params[:status].downcase) if params[:status].present?

  #   # Apply search filter
  #   if params[:search_term].present?
  #     search_term = "%#{params[:search_term].strip.downcase}%"
  #     searchable_conditions = searchable_fields.map { |field| "LOWER(#{model}.#{field}) LIKE :search" }.join(' OR ')
  #     scope = scope.where(searchable_conditions, search: search_term)
  #   end

  #   scope
  # end

  # def apply_sorting(scope, params, sortable_fields)
  #   if params[:sort].present?
  #     sort_field, sort_direction = parse_sort_param(params[:sort])
  #     if sortable_fields.include?(sort_field)
  #       scope = scope.order(sort_field => sort_direction)
  #     else
  #       render json: { error: "Invalid sort parameter" }, status: :bad_request and return
  #     end
  #   else
  #     # Default sorting
  #     scope = scope.order(created_at: :asc)
  #   end
  # end

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
    JWT.decode(token, Rails.application.credentials.secret_key_base)[0].symbolize_keys
  rescue JWT::DecodeError
    nil
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
