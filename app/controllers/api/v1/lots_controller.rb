# frozen_string_literal: true

# app/controllers/api/v1/lots_controller.rb

module Api
  module V1
    # Controller for managing lots within projects
    class LotsController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      load_and_authorize_resource
      before_action :set_project, only: %i[index show create update destroy]
      before_action :set_lot, only: %i[show update destroy]

      # Define allowed sort fields
      SORTABLE_FIELDS = %w[project_id price width name status created_at].freeze
      SEARCHABLE_FIELDS = %w[
        name
        address
        status
        project.name
        project.address
        project.description
        current_contract.applicant_user.full_name
        current_contract.applicant_user.email
        current_contract.applicant_user.identity
        current_contract.creator.full_name
      ].freeze
      MODEL = 'lots'

      # GET /projects/:project_id/lots
      def index
        lots = @project.lots.includes(:project,
                                      :current_contract).includes(current_contract: %i[applicant_user creator])

        # Apply filters based on query parameters
        lots = apply_filters(lots, params, SEARCHABLE_FIELDS)

        # Apply sorting if sort parameters are present
        lots = apply_sorting(lots, params, SORTABLE_FIELDS)

        # Paginate using Pagy
        @pagy, @lots = pagy(lots, items: params[:per_page] || 20, page: params[:page])

        # Map lots with calculated fields (cached for performance)
        # Include max updated_at to invalidate cache when any lot changes
        max_updated_at = @lots.maximum(:updated_at).to_i
        cache_key = "lots_index_#{@project.id}_#{params[:page]}_#{params[:per_page]}_#{params[:search_term]}_#{params[:sort]}_#{max_updated_at}"
        lots_with_calculated_fields = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          @lots.map do |lot|
            lot_json(lot)
          end
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
        service = Lots::CreateLotService.new(project: @project, lot_params:)
        result = service.call

        if result[:success]
          render json: result[:lot], status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_content
        end
      end

      # PUT /projects/:project_id/lots/:id
      # PUT /projects/:project_id/lots/:id
      def update
        return render json: { errors: ['Invalid or missing parameters'] }, status: :bad_request if lot_params.blank?

        service = Lots::UpdateLotService.new(lot: @lot, lot_params:)
        result = service.call

        if result[:success]
          render json: { message: 'Lot updated successfully', lot: result[:lot] }, status: :ok
        else
          render json: { errors: result[:errors] }, status: :unprocessable_content
        end
      end

      # DELETE /projects/:project_id/lots/:id
      def destroy
        service = Lots::DestroyLotService.new(lot: @lot)
        result = service.call

        if result[:success]
          render json: { message: result[:message] }, status: :ok
        else
          render json: { errors: result[:errors] }, status: :unprocessable_content
        end
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Project not found' }, status: :not_found
      end

      def set_lot
        @lot = @project.lots.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Lot not found' }, status: :not_found
      end

      def lot_json(lot)
        {
          id: lot.id,
          contract_id: lot.current_contract&.id,
          project_id: lot.project_id,
          project_name: lot.project&.name || 'N/A',
          name: lot.name,
          address: lot.address,
          contract_created_by: lot.current_contract&.creator&.full_name,
          contract_created_user_id: lot.current_contract&.creator_id,
          reserved_by: lot.current_contract&.applicant_user&.full_name,
          reserved_by_user_id: lot.current_contract&.applicant_user_id,
          measurement_unit: lot.measurement_unit || lot.project.measurement_unit,
          price: lot.effective_price,
          override_price: lot.override_price,
          override_area: lot.override_area,
          north: lot.north,
          east: lot.east,
          west: lot.west,
          length: lot.length,
          width: lot.width,
          dimensions: "#{lot.length} x #{lot.width}",
          area: lot.area_m2,
          status: lot.status.titleize,
          balance: lot.current_contract&.balance,
          registration_number: lot.registration_number,
          note: lot.note,
          created_at: lot.created_at,
          updated_at: lot.updated_at
        }
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
          :override_area,
          :north,
          :east,
          :west,
          :status,
          :measurement_unit,
          :registration_number,
          :note
        )
      end
    end
  end
end
