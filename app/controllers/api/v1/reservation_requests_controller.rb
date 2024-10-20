class Api::V1::ReservationRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reservation_request, only: [:show, :update, :approve, :reject, :cancel]
  before_action :verify_seller_or_admin, only: [:create, :approve, :reject, :cancel]

  # GET /api/v1/reservation_requests
  def index
    if current_user.admin?
      @reservation_requests = ReservationRequest.all
    else
      @reservation_requests = ReservationRequest.where(user: current_user)
    end
    render json: @reservation_requests, include: :documents
  end

  # POST /api/v1/reservation_requests
  def create
    service = Reservations::CreateReservationRequestService.new(
      lot_id: reservation_request_params[:lot_id],
      payment_term: reservation_request_params[:payment_term],
      financing_type: reservation_request_params[:financing_type],  # ahora puede ser direct, bank, o cash
      user: current_user,
      documents: reservation_request_params[:documents]
    )

    result = service.call

    if result[:success]
      render json: { message: 'Reservation request created successfully.', reservation: result[:reservation] }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/reservation_requests/:id/approve
  def approve
    if @reservation_request.update(status: 'approved')
      contract = generate_contract(@reservation_request)
      render json: { message: 'Reservation approved and contract sent.', contract: contract }, status: :ok
    else
      render json: { errors: @reservation_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/reservation_requests/:id/reject
  def reject
    if @reservation_request.update(status: 'rejected')
      render json: { message: 'Reservation rejected.' }, status: :ok
    else
      render json: { errors: @reservation_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/reservation_requests/:id/cancel
  def cancel
    if @reservation_request.update(status: 'cancelled')
      render json: { message: 'Reservation request cancelled.' }, status: :ok
    else
      render json: { errors: @reservation_request.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_reservation_request
    @reservation_request = ReservationRequest.find(params[:id])
  end

  def reservation_request_params
    params.require(:reservation_request).permit(:lot_id, :payment_term, :financing_type, documents: [])
  end

  def verify_seller_or_admin
    unless current_user.seller? || current_user.admin?
      render json: { error: 'Unauthorized access!' }, status: :forbidden
    end
  end

  # Generar contrato y enviarlo por correo
  def generate_contract(reservation_request)
    markdown_template = File.read(Rails.root.join('app', 'templates', 'contract_template.md'))
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    contract = renderer.render(markdown_template % {
      user_name: reservation_request.user.name,
      lot_name: reservation_request.lot.name,
      price: reservation_request.lot.price
    })

    # Aquí se puede enviar el contrato por correo
    UserMailer.contract_email(reservation_request.user, contract).deliver_now
    contract
  end
end
