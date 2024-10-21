# app/controllers/api/v1/projects_controller.rb

class Api::V1::ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update, :destroy]
  load_and_authorize_resource

  # GET /api/v1/projects
  def index
    if params[:query].present?
      @projects = Project.where('name LIKE ? OR description LIKE ? OR address LIKE ?', "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%")
    else
      @projects = Project.all
    end
    render json: @projects
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
    params.require(:project).permit(:name, :description, :address, :lot_count, :price_per_square_foot, :interest_rate)
  end
end
