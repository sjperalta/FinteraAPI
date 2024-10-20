# app/controllers/lots_controller.rb

class Api::V1::LotsController < ApplicationController
  before_action :set_project
  before_action :set_lot, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  #load_and_authorize_resource :lot, through: :project
  load_and_authorize_resource

  # GET /projects/:project_id/lots
  def index
    @lots = @project.lots
    render json: @lots
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
  def update
    service = Lots::UpdateLotService.new(lot: @lot, lot_params: lot_params)
    result = service.call

    if result[:success]
      render json: result[:lot], status: :ok
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
  end

  def set_lot
    @lot = @project.lots.find(params[:id])
  end

  def lot_params
    params.require(:lot).permit(:name, :length, :width, :price)
  end
end
