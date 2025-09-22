# app/controllers/api/v1/lots_controller.rb

class Api::V1::LotsController < ApplicationController
  include Filterable, Sortable, Pagy::Backend
  load_and_authorize_resource
  before_action :set_project, only: [:index, :show, :create, :update, :destroy]
  before_action :set_lot, only: [:show, :update, :destroy]

  # Define allowed sort fields
  SORTABLE_FIELDS = %w[project_id price width name status created_at].freeze
  SEARCHABLE_FIELDS = %w[name status].freeze
  MODEL = 'lots'.freeze

  # GET /projects/:project_id/lots
  def index
    lots = @project.lots.includes(:project, :current_contract)

    # Apply filters based on query parameters
    lots = apply_filters(lots, params, SEARCHABLE_FIELDS)

    # Apply sorting if sort parameters are present
    lots = apply_sorting(lots, params, SORTABLE_FIELDS)

    # Paginate using Pagy
    @pagy, @lots = pagy(lots, items: params[:per_page] || 20, page: params[:page])

    # Map lots with calculated fields
    lots_with_calculated_fields = @lots.map do |lot|

      contract = lot.current_contract
      reservation_text = if !contract&.applicant_user.nil?
                            "#{contract.applicant_user.full_name}##{contract.applicant_user.id}"
                          else
                            "N/A"
                          end

      {
        id: lot.id,
        contract_id: contract&.id,
        project_id: lot.project_id,
        project_name: lot.project&.name || "N/A",
        name: lot.name,
        address: lot.address,
        reserved_by: reservation_text,
        measurement_unit: lot.measurement_unit || lot.project.measurement_unit,
        price: lot.price,
        length: lot.length,
        width: lot.width,
        dimensions: "#{lot.length} x #{lot.width}",
        area: lot.area_m2,
        status: lot.status.titleize,  # Capitalize for better readability
        balance: contract&.balance || lot.price,
        registration_number: lot.registration_number,
        note: lot.note,
        created_at: lot.created_at,
        updated_at: lot.updated_at
      }
    end

    # Pagy metadata
    pagination_metadata = pagy_metadata(@pagy)

    render json: {
      lots: lots_with_calculated_fields,
      pagination: pagination_metadata
    }, status: :ok
  end

  # GET /projects/:project_id/lots/:id
  def show
    render json: @lot
  end

  # POST /projects/:project_id/lots
  def create
    service = Lots::CreateLotService.new(project: @project, lot_params: lot_params)
    result = service.call

    if result[:success]
      render json: result[:lot], status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # PUT /projects/:project_id/lots/:id
  # PUT /projects/:project_id/lots/:id
  def update
    if lot_params.blank?
      return render json: { errors: ['Invalid or missing parameters'] }, status: :bad_request
    end

    service = Lots::UpdateLotService.new(lot: @lot, lot_params: lot_params)
    result = service.call

    if result[:success]
      render json: { message: 'Lot updated successfully', lot: result[:lot] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # DELETE /projects/:project_id/lots/:id
  def destroy
    service = Lots::DestroyLotService.new(lot: @lot)
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end

  def set_lot
    @lot = @project.lots.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Lot not found" }, status: :not_found
  end

  def lot_params
    return {} unless params[:lot].is_a?(ActionController::Parameters)
    params.require(:lot).permit(
      :name,
      :length,
      :width,
      :price,
      :address,
      :override_price,
      :status,
      :measurement_unit,
      :registration_number,
      :note
    )
  end
end
