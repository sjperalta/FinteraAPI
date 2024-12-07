class Api::V1::ContractsController < ApplicationController
  before_action :set_project
  before_action :set_lot
  before_action :set_contract, only: [:show, :reject, :approve, :cancel]
  load_and_authorize_resource

  # GET /api/v1/projects/:project_id/lots/:lot_id/contracts
  def index
    @contracts = @lot.contracts
    render json: @contracts
  end

  # GET /api/v1/projects/:project_id/lots/:lot_id/contracts/:id
  def show
    render json: @contract
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts
  def create
    service = Contracts::CreateContractService.new(
      lot: @lot,
      contract_params: contract_params,
      documents: contract_documents,
      current_user: current_user # Pasar el current_user al service
    )
    result = service.call

    if result[:success]
      render json: result[:contract], status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/approve
  def approve
    service = Contracts::ApproveContractService.new(
      contract: @contract,
      current_user: current_user
    )
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/reject
  def reject
    service = Contracts::RejectContractService.new(contract: @contract)
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/cancel
  def cancel
    service = Contracts::CancelContractService.new(contract: @contract)
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
    #@lot = @project.lots.find(params[:lot_id])
    @lot = Lot.find(params[:lot_id])
  end

  def set_contract
    @contract = @lot.contracts.find(params[:id])
  end

  def contract_params
    params.require(:contract).permit(:payment_term, :financing_type, :applicant_user_id, :reserve_amount, :down_payment)
  end

  # Permitir la carga de múltiples documentos
  def contract_documents
    params[:contract][:documents] || []
  end
end
