# app/controllers/payments_controller.rb

class Api::V1::PaymentsController < ApplicationController
  include Filterable, Sortable, Pagy::Backend
  load_and_authorize_resource
  before_action :set_payment, only: [:show, :approve, :reject, :upload_receipt]

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
        only: [:id, :description, :amount, :interest_amount, :status, :due_date, :contract_id, :created_at, :approved_at, :payment_date],
        include: {
          contract: {
            only: [:id, :balance, :status, :created_at, :currency]
          }
        }
      ),
      pagination: pagy_metadata(pagy)
    }, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue StandardError => e
    render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
  end

  # GET /payments/:id
  def show
    render json: @payment
  end

  # POST /payments/:id/approve
  def approve
    service = Payments::ApprovePaymentService.new(payment: @payment)

    if service.call
      render json: { message: 'Pago aprobado exitosamente' }, status: :ok
    else
      render json: { error: 'No se pudo aprobar el pago' }, status: :unprocessable_entity
    end
  end

  # POST /payments/:id/reject
  def reject
    service = Payments::RejectPaymentService.new(payment: @payment)

    if service.call
      render json: { message: 'Pago rechazado' }, status: :ok
    else
      render json: { error: 'No se pudo rechazar el pago' }, status: :unprocessable_entity
    end
  end

  # POST /payments/:id/upload_receipt
  def upload_receipt
    if params[:receipt].present?
      service = Payments::UploadReceiptService.new(payment: @payment, receipt: params[:receipt], user: current_user)

      if service.call
        render json: { message: 'Comprobante subido exitosamente, esperando aprobación' }, status: :ok
      else
        render json: { error: 'No se pudo subir el comprobante' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'No se proporcionó un archivo para el comprobante' }, status: :unprocessable_entity
    end
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pago no encontrado' }, status: :not_found
  end
end
