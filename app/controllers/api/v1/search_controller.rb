module Api
  module V1
    class SearchController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/search/contracts
      def contracts
        contracts = Contract.all

        # Apply filters based on query parameters
        contracts = contracts.where('customer_name LIKE ?', "%#{params[:customer_name]}%") if params[:customer_name].present?
        contracts = contracts.where('DATE(created_at) = ?', params[:date]) if params[:date].present?
        contracts = contracts.where('amount >= ?', params[:min_amount]) if params[:min_amount].present?
        contracts = contracts.where('amount <= ?', params[:max_amount]) if params[:max_amount].present?
        contracts = contracts.where(status: params[:status]) if params[:status].present?

         # Mapping logic: Add custom fields to the response
         mapped_contracts = contracts.map do |contract|
          {
            id: contract.id,
            customer_name: contract.applicant_user&.full_name,
            amount: contract.amount,
            status: contract.status,
            created_at: contract.created_at.strftime('%Y-%m-%d'),  # Example: Formatting the date
            total_payments: contract.payments.count,                # Example: Adding a calculated field
            balance: contract.balance,      # Example: Total amount paid
            lot_id: contract.lot.id,
            project_id: contract.lot.project.id
          }
        end

        render json: mapped_contracts, status: :ok
      end
    end
  end
end
