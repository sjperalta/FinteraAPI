# app/controllers/payments_controller.rb

class Api::V1::PaymentsController < ApplicationController
  before_action :set_contract
  before_action :set_payment, only: [:show, :approve, :reject, :upload_receipt]
  load_and_authorize_resource

  # GET /projects/:project_id/lots/:lot_id/contracts/:contract_id/payments
  def index
    @payments = @contract.payments
    render json: @payments
  end

  # GET /projects/:project_id/lots/:lot_id/contracts/:contract_id/payments/:id
  def show
    render json: @payment
  end

  # POST /projects/:project_id/lots/:lot_id/contracts/:contract_id/payments/:id/approve
  def approve
    service = Payments::ApprovePaymentService.new(payment: @payment)

    if service.call
      render json: { message: 'Pago aprobado exitosamente' }, status: :ok
    else
      render json: { error: 'No se pudo aprobar el pago' }, status: :unprocessable_entity
    end
  end

  # POST /projects/:project_id/lots/:lot_id/contracts/:contract_id/payments/:id/reject
  def reject
    service = Payments::RejectPaymentService.new(payment: @payment)

    if service.call
      render json: { message: 'Pago rechazado' }, status: :ok
    else
      render json: { error: 'No se pudo rechazar el pago' }, status: :unprocessable_entity
    end
  end

  # POST /projects/:project_id/lots/:lot_id/contracts/:contract_id/payments/:id/upload_receipt
  def upload_receipt
    if params[:receipt].present?
      service = Payments::UploadReceiptService.new(payment: @payment, receipt: params[:receipt])

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

  def set_contract
    @contract = Contract.find(params[:contract_id])
  end

  def set_payment
    @payment = @contract.payments.find(params[:id])
  end
end
