class Api::V1::ReservationsController < ApplicationController
  before_action :set_project
  before_action :set_lot
  before_action :set_reservation, only: [:show, :update, :destroy, :approve, :reject, :cancel]

  # POST /api/v1/projects/:project_id/lots/:lot_id/reservations
  def create
    service = Reservations::CreateReservationService.new(
      lot: @lot,
      reservation_params: reservation_params,
      documents: reservation_documents,
      current_user: current_user # Pasar el current_user al service
    )
    result = service.call

    if result[:success]
      render json: result[:reservation], status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/reservations/:id/approve
  def approve
    service = Reservations::ApproveReservationService.new(reservation: @reservation)
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/reservations/:id/reject
  def reject
    service = Reservations::RejectReservationService.new(reservation: @reservation)
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/projects/:project_id/lots/:lot_id/reservations/:id/cancel
  def cancel
    service = Reservations::CancelReservationService.new(reservation: @reservation)
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
    @lot = @project.lots.find(params[:lot_id])
  end

  def set_reservation
    @reservation = @lot.reservations.find(params[:id])
  end

  def reservation_params
    params.require(:reservation_request).permit(:payment_term, :financing_type, :applicant_user_id)
  end

  # Permitir la carga de múltiples documentos
  def reservation_documents
    params[:reservation_request][:documents] || []
  end
end
