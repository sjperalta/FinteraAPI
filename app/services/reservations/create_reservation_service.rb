# app/services/reservations/create_reservation_service.rb

module Reservations
  class CreateReservationService
    def initialize(lot:, reservation_params:, documents:, current_user:)
      @lot = lot
      @reservation_params = reservation_params
      @documents = documents
      @current_user = current_user
    end

    def call
      reservation = @lot.reservations.build(@reservation_params)
      reservation.creator = @current_user

      if reservation.save
        reservation.documents.attach(@documents) if @documents.present?
        { success: true, reservation: reservation }
      else
        { success: false, errors: reservation.errors.full_messages }
      end
    end
  end
end
