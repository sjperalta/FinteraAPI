# frozen_string_literal: true

# app/controllers/api/v1/projects_controller.rb

module Api
  module V1
    class ProjectsController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      before_action :authenticate_user!
      load_and_authorize_resource
      before_action :set_project, only: %i[show update destroy]

      # Define fields allowed for search & sort
      SEARCHABLE_FIELDS = %w[name description address].freeze
      SORTABLE_FIELDS   = %w[name created_at project_type price_per_square_unit].freeze

      # GET /api/v1/projects
      def index
        # Base scope
        projects = Project.all

        # Apply filtering based on query parameters & searchable fields
        projects = apply_filters(projects, params, SEARCHABLE_FIELDS)

        # Apply sorting based on sortable fields
        projects = apply_sorting(projects, params, SORTABLE_FIELDS)

        # Paginate results using Pagy
        @pagy, @projects = pagy(
          projects,
          items: (params[:per_page] || 20).to_i,
          page: params[:page]
        )

        # Modificar la respuesta para incluir campos calculados
        projects_with_calculated_fields = @projects.map do |project|
          total_area = project.lots.sum(&:area_m2)
          {
            id: project.id,
            name: project.name,
            description: project.description,
            project_type: project.project_type,
            price_per_square_unit: project.price_per_square_unit,
            address: project.address,
            total_lots: project.lot_count,
            available: project.lots.where(status: 'available').count,
            reserved: project.lots.where(status: 'reserved').count,
            total_area:,
            delivery_date: project.delivery_date,
            created_at: project.created_at,
            updated_at: project.updated_at
          }
        end

        render json: {
          projects: projects_with_calculated_fields,
          pagination: pagy_metadata(@pagy)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue StandardError
        render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
      end

      # GET /api/v1/projects/:id
      def show
        render json: @project
      end

      # POST /api/v1/projects
      def create
        service = Projects::CreateProjectService.new(project_params)
        result = service.call

        if result[:success]
          render json: { message: 'Project created successfully', project: result[:project] }, status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/projects/:id
      def update
        if @project.update(project_params)
          render json: { message: 'Project updated successfully' }, status: :ok
        else
          render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/projects/:id
      def destroy
        @project.destroy
        render json: { message: 'Project deleted successfully' }, status: :ok
      end

      private

      def set_project
        @project = Project.find(params[:id])
      end

      def project_params
        params.require(:project).permit(
          :name,
          :description,
          :project_type,
          :address,
          :lot_count,
          :price_per_square_unit,
          :measurement_unit,
          :interest_rate,
          :commission_rate,
          :delivery_date
        )
      end
    end
  end
end
