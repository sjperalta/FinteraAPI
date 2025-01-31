# app/controllers/api/v1/contracts_controller.rb

class Api::V1::ContractsController < ApplicationController
  include Filterable, Sortable, Pagy::Backend
  load_and_authorize_resource
  before_action :set_project, only: [:create, :approve, :reject]
  before_action :set_lot, only: [:create, :approve, :reject]
  before_action :set_contract, only: [:show, :approve, :reject]

  # Define sortable and searchable fields to prevent SQL injection and ensure valid operations
  SORTABLE_FIELDS = %w[applicant_user_id created_at lot_id payment_term financing_type amount balance reserve_amount status].freeze
  SEARCHABLE_FIELDS = %w[financing_type status].freeze

  # GET /api/v1/contracts?search_term=xxx&sort=xx-asc
  def index
    # Fetch contracts related to the specified lot with eager loading to prevent N+1 queries
    contracts = Contract.all.includes(:lot)

    # If user is not admin, narrow scope to contracts owned by the current user
    unless current_user.admin?
      contracts = contracts.where(creator_id: current_user.id)
    end

    # Apply search if search_term is present
    contracts = apply_filters(contracts, params, SEARCHABLE_FIELDS)

    # Apply sorting if sort parameters are present
    contracts = apply_sorting(contracts, params, SORTABLE_FIELDS)

    # Paginate the contracts using Pagy
    @pagy, @contracts = pagy(contracts, items: params[:per_page] || 20, page: params[:page])

    # Map contracts with additional calculated fields if necessary
    contracts_with_calculated_fields = @contracts.map do |contract|
      {
        id: contract.id,
        contract_id: contract.id,
        project_id: contract&.lot&.project_id,
        lot_id: contract.lot_id,
        lot_name: contract&.lot&.name,
        applicant_user_id: contract.applicant_user_id,
        created_by: contract&.creator&.full_name,
        customer_name: contract.applicant_user.full_name,
        payment_term: contract.payment_term,
        financing_type: contract.financing_type,
        reserve_amount: contract.reserve_amount,
        down_payment: contract.down_payment,
        status: contract.status.titleize,
        balance: contract.balance,
        documents: contract.documents, # Assuming there's a documents association or attribute
        created_at: contract.created_at,
        updated_at: contract.updated_at
        # Add more fields or associations as needed
      }
    end

    # Render JSON response with contracts and pagination metadata
    render json: {
      contracts: contracts_with_calculated_fields,
      pagination: pagy_metadata(@pagy)
    }, status: :ok
  end

  # GET /api/v1/projects/:project_id/lots/:lot_id/contracts/:id
  def show
    render json: contract_details(@contract), status: :ok
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts
  def create
    service = Contracts::CreateContractService.new(
      lot: @lot,
      contract_params: contract_params,
      user_params: user_params,
      documents: contract_documents,
      current_user: current_user
    )

    result = service.call

    if result[:success]
      render json: {
        message: 'Contract created successfully',
        contract: contract_details(result[:contract])
      }, status: :created
    else
      render json: {
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/approve
  def approve
    authorize! :approve, @contract

    if @contract.may_approve?
      @contract.approve!
      render json: {
        message: 'Contrato aprobado exitosamente',
        contract: contract_details(@contract)
      }, status: :ok
    else
      render json: {
        error: 'No se puede aprobar el contrato en su estado actual',
        status: @contract.status
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/reject
  def reject
    authorize! :reject, @contract

    if @contract.may_reject?
      @contract.reject!
      render json: {
        message: 'Contrato rechazado exitosamente',
        contract: contract_details(@contract)
      }, status: :ok
    else
      render json: {
        error: 'No se puede rechazar el contrato en su estado actual',
        status: @contract.status
      }, status: :unprocessable_entity
    end
  end

  def cancel
    authorize! :cancel, @contract

    if @contract.may_cancel?
      @contract.cancel!
      render json: {
        message: 'Contrato cancelado exitosamente',
        contract: contract_details(@contract)
      }, status: :ok
    else
      render json: {
        error: 'No se puede cancelar el contrato en su estado actual',
        status: @contract.status
      }, status: :unprocessable_entity
    end
  end

  private

  # Set the project based on project_id parameter
  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end

  # Set the lot based on lot_id parameter within the project
  def set_lot
    @lot = @project.lots.find(params[:lot_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Lot not found in the specified project" }, status: :not_found
  end

  # Set the contract based on id parameter within the lot
  def set_contract
    @contract = @lot.contracts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Contract not found in the specified lot" }, status: :not_found
  end

  # Strong parameters for contract creation
  def contract_params
    params.require(:contract).permit(
      :payment_term,
      :financing_type,
      :applicant_user_id,
      :reserve_amount,
      :down_payment,
      :currency
    )
  end

  # Strong parameters for user associated with the contract
  def user_params
    params.require(:user).permit(
      :full_name,
      :phone,
      :identity,
      :rtn,
      :email
    )
  end

  # Handle contract documents
  def contract_documents
    params.dig(:contract, :documents) || []
  end

  # Structure contract details for JSON response
  def contract_details(contract)
    {
      id: contract.id,
      contract_id: contract.id,
      project_id: contract&.lot&.project_id,
      lot_id: contract.lot_id,
      applicant_user_id: contract.applicant_user_id,
      payment_term: contract.payment_term,
      financing_type: contract.financing_type,
      reserve_amount: contract.reserve_amount,
      down_payment: contract.down_payment,
      status: contract.status.titleize,
      balance: contract.balance,
      documents: contract.documents,
      created_at: contract.created_at,
      updated_at: contract.updated_at,
      approved_at: contract.approved_at
      # Add more fields or associations as needed
    }
  end
end
