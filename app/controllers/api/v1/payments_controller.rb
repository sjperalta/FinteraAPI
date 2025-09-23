# frozen_string_literal: true

# app/controllers/payments_controller.rb

module Api
  module V1
    class PaymentsController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      before_action :authenticate_user!
      load_and_authorize_resource
      before_action :set_payment, only: %i[show approve reject upload_receipt apply]

      # Define searchable and sortable fields
      SEARCHABLE_FIELDS = %w[status due_date amount contract_id].freeze
      SORTABLE_FIELDS = %w[created_at amount due_date status].freeze

      # GET /payments
      def index
        # Initialize the scope with necessary associations and select relevant fields
        payments = Payment.joins(:contract).includes(:contract).select('payments.*, contracts.balance, contracts.status as contract_status, contracts.created_at as contract_created_at')

        # Apply filtering based on searchable fields
        payments = apply_filters(payments, params, SEARCHABLE_FIELDS)

        # Apply sorting based on sortable fields
        payments = apply_sorting(payments, params, SORTABLE_FIELDS)

        # Paginate the results using Pagy
        pagy, payments = pagy(payments, items: params[:per_page] || Pagy::DEFAULT[:items], page: params[:page])

        # Prepare the JSON response with payments and pagination metadata
        render json: {
          payments: payments.as_json(
            only: %i[id description amount interest_amount status due_date contract_id created_at
                     approved_at payment_date],
            include: {
              contract: {
                only: %i[id balance status created_at currency]
              }
            }
          ),
          pagination: pagy_metadata(pagy)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue StandardError
        render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
      end

      # GET /payments/:id
      def show
        render json: @payment
      end

      # POST /payments/:id/approve
      def approve
        service = Payments::ApprovePaymentService.new(payment: @payment)
        result = service.call

        if result[:success]
          render json: {
            message: result[:message],
            payment: result[:payment]
          }, status: :ok
        else
          render json: {
            error: result[:message],
            errors: result[:errors]
          }, status: :unprocessable_content
        end
      end

      # POST /payments/:id/reject
      def reject
        if @payment.may_reject? && @payment.reject!
          render json: { message: 'Payment rejected successfully' }, status: :ok
        else
          render json: { error: 'Failed to reject payment' }, status: :unprocessable_content
        end
      end

      # POST /payments/:id/upload_receipt
      def upload_receipt
        return render json: { error: 'Receipt file is required' }, status: :bad_request unless params[:receipt]

        @payment.document.attach(params[:receipt])

        if @payment.may_submit? && @payment.submit!
          render json: { message: 'Receipt uploaded and payment submitted successfully' }, status: :ok
        else
          render json: { error: 'Failed to process payment submission' }, status: :unprocessable_content
        end
      end

      # POST /payments/:id/apply
      def apply
        # Handle both nested and flat parameter structures
        payment_data = params.fetch(:payment, params)
        payment_params = payment_data.permit(:amount, :interest_amount, :total_amount)

        # Assign attributes from params
        @payment.assign_attributes(payment_params)
        @payment.payment_date = Time.current

        # Check if the state transition is possible before attempting
        unless @payment.may_pay?
          render json: {
            error: 'Cannot apply payment.',
            message: "Payment is in '#{@payment.status}' status and cannot be paid directly."
          }, status: :unprocessable_content
          return
        end

        # Attempt to transition state and save. The `pay!` method will save the record.
        if @payment.pay!
          render json: {
            message: 'Payment applied successfully',
            payment: @payment.as_json(
              only: %i[id description amount interest_amount status due_date contract_id created_at
                       approved_at payment_date],
              include: {
                contract: {
                  only: %i[id balance status created_at currency]
                }
              }
            )
          }, status: :ok
        else
          # This block may not be reached if pay! raises an exception, but is good for safety
          render json: {
            error: 'Failed to apply payment',
            errors: @payment.errors.full_messages
          }, status: :unprocessable_content
        end
      rescue AASM::InvalidTransition => e
        render json: { error: 'State transition failed', message: e.message }, status: :unprocessable_content
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: 'Validation failed', errors: e.record.errors.full_messages }, status: :unprocessable_content
      rescue StandardError => e
        Rails.logger.error "Apply Payment Error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
      end

      # Add this new action
      def download_receipt
        authorize! :read, @payment

        if @payment.document.attached?
          redirect_to url_for(@payment.document)
        else
          render json: { error: 'No document attached' }, status: :not_found
        end
      end

      private

      def set_payment
        @payment = Payment.with_attached_document.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Pago no encontrado' }, status: :not_found
      end
    end
  end
end
