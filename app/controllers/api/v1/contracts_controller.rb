# frozen_string_literal: true

# app/controllers/api/v1/contracts_controller.rb
module Api
  module V1
    # Controller for managing contracts
    class ContractsController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      include ContractCacheInvalidation

      load_and_authorize_resource
      before_action :set_project, only: %i[create approve reject cancel reopen capital_repayment ledger update]
      before_action :set_lot, only: %i[create approve reject cancel reopen capital_repayment ledger update]
      before_action :set_contract, only: %i[show approve reject cancel reopen capital_repayment ledger update]

      # Define sortable and searchable fields to prevent SQL injection and ensure valid operations
      SORTABLE_FIELDS = %w[applicant_user_id contracts.created_at lot_id payment_term financing_type status
                           amount].freeze
      SEARCHABLE_FIELDS = %w[
        contracts.created_at
        status
        financing_type
        applicant_user.identity
        applicant_user.phone
        applicant_user.full_name
        applicant_user.email
        creator.full_name
        creator.email
        lot.name
        lot.address
        lot.project.name
      ].freeze

      # GET /api/v1/contracts?search_term=xxx&sort=xx-asc
      def index
        # Start with a relation and apply access scope, filters, and sorting before loading
        contracts = Contract.all

        # If user is not admin, narrow scope to contracts created by the current user
        contracts = contracts.where(creator_id: current_user.id) unless current_user.admin?

        # Apply search and sorting on the relation (ensure these methods use efficient queries)
        contracts = apply_filters(contracts, params, SEARCHABLE_FIELDS)
        contracts = apply_sorting(contracts, params, SORTABLE_FIELDS)

        contracts = contracts.includes(:applicant_user, :creator, :payments, lot: :project)

        # Paginate the contracts using Pagy (applied after filtering/sorting/includes for efficiency)
        per_page = (params[:per_page].presence || 20).to_i
        per_page = 20 if per_page <= 0

        requested_page = params[:page].to_i
        requested_page = 1 if requested_page <= 0

        # Calculate total pages to avoid Pagy::OverflowError when client requests too-large page
        total_count = contracts.count
        total_pages = (total_count.to_f / per_page).ceil

        # If there are no results, use page 1. Otherwise clamp to last page when requested_page > total_pages
        page_to_use = if total_pages.zero?
                        1
                      else
                        [requested_page, total_pages].min
                      end

        @pagy, @contracts = pagy(contracts, items: per_page, page: page_to_use)

        # Cache the contracts JSON mapping for performance
        # Cache is invalidated proactively by services when contracts/payments are modified
        # Include current_user.id to separate cache per user (admins see all, users see their own)
        cache_key = ['contracts', 'index', current_user.id, params[:page], params[:per_page],
                     params[:search_term], params[:sort]].join('/')
        contracts_with_calculated_fields = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          @contracts.map { |c| contract_json(c) }
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
        authorize! :create, Contract

        service = Contracts::CreateContractService.new(
          lot: @lot,
          contract_params:,
          user_params:,
          documents: contract_documents,
          current_user:
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
          }, status: :unprocessable_content
        end
      end

      # PATCH/PUT /api/v1/projects/:project_id/lots/:lot_id/contracts/:id
      def update
        authorize! :update, @contract

        # Only allow updates for contracts in draft or pending status
        unless @contract.status.in?(%w[pending submitted rejected])
          return render json: {
            error: 'Solo se pueden modificar contratos en estado pendiente, enviado o rechazado',
            status: @contract.status
          }, status: :unprocessable_content
        end

        if @contract.update(update_contract_params)
          # Invalidate cache after contract update
          invalidate_contract_cache(@contract)

          render json: {
            message: 'Contrato actualizado exitosamente',
            contract: contract_details(@contract)
          }, status: :ok
        else
          render json: {
            errors: @contract.errors.full_messages
          }, status: :unprocessable_content
        end
      end

      # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/approve
      def approve
        authorize! :approve, @contract

        if @contract.may_approve?
          @contract.approve!

          # Invalidate cache after contract approval
          invalidate_contract_cache(@contract)

          render json: {
            message: 'Contrato aprobado exitosamente',
            contract: contract_details(@contract)
          }, status: :ok
        else
          render json: {
            error: 'No se puede aprobar el contrato en su estado actual',
            status: @contract.status
          }, status: :unprocessable_content
        end
      end

      # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/reject
      def reject
        authorize! :reject, @contract

        if @contract.may_reject?
          @contract.reject!
          @contract.rejection_reason = params[:reason] if params[:reason].present?
          @contract.save!

          # Invalidate cache after contract rejection
          invalidate_contract_cache(@contract)

          render json: {
            message: params[:reason].present? ? "Contrato rechazado: #{params[:reason]}" : 'Contrato rechazado exitosamente',
            contract: contract_details(@contract)
          }, status: :ok
        else
          render json: {
            error: 'No se puede rechazar el contrato en su estado actual',
            status: @contract.status
          }, status: :unprocessable_content
        end
      end

      # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/cancel
      def cancel
        authorize! :cancel, @contract

        service = Contracts::CancelContractService.new(
          contract: @contract,
          current_user:,
          reason: params[:reason]
        )

        result = service.call

        if result[:success]
          render json: {
            message: result[:message],
            contract: contract_details(result[:contract])
          }, status: :ok
        else
          render json: {
            errors: result[:errors]
          }, status: :unprocessable_content
        end
      end

      # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/reopen
      def reopen
        authorize! :reopen, @contract

        if @contract.may_re_open?
          @contract.re_open!

          # Invalidate cache after contract reopen
          invalidate_contract_cache(@contract)

          render json: {
            message: 'Contrato reabierto exitosamente',
            contract: contract_details(@contract)
          }, status: :ok
        else
          render json: {
            error: 'No se puede reabrir el contrato en su estado actual',
            status: @contract.status
          }, status: :unprocessable_content
        end
      end

      # GET /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/ledger
      def ledger
        authorize! :read, @contract
        render json: @contract.ledger_entries.by_date.as_json(only: %i[id amount description entry_type entry_date payment_id]),
               status: :ok
      end

      # Capital repayment, the client pays an extra amount to reduce the principal
      # POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/capital_repayment
      def capital_repayment
        authorize! :update, @contract

        params.require(:contract).permit(:capital_repayment_amount)
        amount = params[:contract][:capital_repayment_amount]

        service = Contracts::CapitalRepaymentService.new(
          contract: @contract,
          amount:,
          current_user:
        )

        result = service.call

        if result[:success]
          render json: {
            message: result[:message],
            contract: contract_details(result[:contract]),
            reajusted_payments_count: result[:reajusted_payments_count],
            reajusted_payment_ids: result[:reajusted_payment_ids]
          }, status: :ok
        else
          render json: { errors: result[:errors] }, status: :unprocessable_content
        end
      end

      private

      # Set the project based on project_id parameter
      def set_project
        @project = Project.find(params[:project_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Project not found' }, status: :not_found
      end

      # Set the lot based on lot_id parameter within the project
      def set_lot
        @lot = @project.lots.find(params[:lot_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Lot not found in the specified project' }, status: :not_found
      end

      # Set the contract based on id parameter within the lot
      def set_contract
        @contract = @lot.contracts.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Contract not found in the specified lot' }, status: :not_found
      end

      # Strong parameters for contract creation
      def contract_params
        params.require(:contract).permit(
          :payment_term,
          :financing_type,
          :applicant_user_id,
          :reserve_amount,
          :down_payment,
          :currency,
          :rejection_reason,
          :note
        )
      end

      # Strong parameters for contract updates (limited fields)
      def update_contract_params
        params.require(:contract).permit(
          :payment_term,
          :reserve_amount,
          :down_payment
        )
      end

      # Strong parameters for user associated with the contract
      def user_params
        params.require(:user).permit(
          :full_name,
          :phone,
          :identity,
          :rtn,
          :email,
          :address
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
          project_name: contract&.lot&.project&.name,
          lot_id: contract.lot_id,
          applicant_user_id: contract.applicant_user_id,
          applicant_name: contract.applicant_user&.full_name,
          amount: contract.amount,
          payment_term: contract.payment_term,
          financing_type: contract.financing_type,
          reserve_amount: contract.reserve_amount,
          down_payment: contract.down_payment,
          status: contract.status.titleize,
          balance: contract.balance,
          documents: contract.documents,
          created_at: contract.created_at,
          updated_at: contract.updated_at,
          approved_at: contract.approved_at,
          rejection_reason: contract.rejection_reason,
          note: contract.note
          # Add more fields or associations as needed
        }
      end

      def contract_json(contract)
        # Pre-load payments once per contract (already eager-loaded)
        payments = contract.payments.order(:due_date)

        # Calculate payment_schedule (in-memory mapping; consider caching if heavy)
        payment_schedule = payments.map do |p|
          overdue_days = p.due_date < Date.current && p.status == 'pending' ? (Date.current - p.due_date).to_i : 0
          {
            id: p.id,
            due_date: p.due_date,
            amount: p.amount,
            status: p.status.titleize,
            payment_type: p.payment_type.humanize,
            paid_amount: p.paid_amount || 0,
            interest_amount: p.interest_amount || 0,
            overdue_days:,
            description: p.description
          }
        end

        # Calculate totals (fix: explicitly handle nil values to avoid BigDecimal coercion errors)
        total_interest = payments.sum { |p| p.interest_amount || 0 }
        total_paid = payments.where(status: 'paid').sum { |p| p.paid_amount || 0 }

        {
          id: contract.id,
          contract_id: contract.id,
          project_id: contract&.lot&.project_id,
          project_name: contract&.lot&.project&.name,
          project_address: contract&.lot&.project&.address,
          lot_id: contract.lot_id,
          lot_name: contract&.lot&.name,
          lot_address: contract&.lot&.address,
          lot_price: contract&.lot&.price,
          lot_override_price: contract&.lot&.override_price,
          applicant_user_id: contract.applicant_user_id,
          applicant_name: contract.applicant_user&.full_name,
          applicant_phone: contract.applicant_user&.phone,
          applicant_credit_score: contract.applicant_user&.credit_score,
          applicant_identity: mask_identity(contract.applicant_user&.identity),
          created_by: contract&.creator&.full_name,
          approved_at: contract.approved_at,
          amount: contract.amount,
          payment_term: contract.payment_term,
          financing_type: contract.financing_type,
          reserve_amount: contract.reserve_amount,
          down_payment: contract.down_payment,
          status: contract.status.titleize,
          rejection_reason: contract.rejection_reason,
          cancellation_notes: contract.note,
          balance: contract.balance,
          total_interest_collected: total_interest,
          total_paid:,
          documents: contract.documents,
          created_at: contract.created_at,
          updated_at: contract.updated_at,
          note: contract.note,
          payment_schedule:
        }
      end

      # Masks an identity string keeping the first 4 and last 3 chars visible.
      # For very short values it returns asterisks of the same length.
      def mask_identity(identity)
        return nil if identity.nil?

        s = identity.to_s
        return '*' * s.length if s.length <= 4

        "#{s[0, 4]}#{'*' * (s.length - 4)}#{s[-3, 3]}"
      end
    end
  end
end
