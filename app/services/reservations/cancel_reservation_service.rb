# app/services/reservations/cancel_reservation_service.rb

module Reservations
  class CancelReservationService
    def initialize(reservation:)
      @reservation = reservation
    end

    def call
      if @reservation.update(status: 'cancelled')
        { success: true, message: 'Solicitud cancelada' }
      else
        { success: false, errors: @reservation.errors.full_messages }
      end
    end
  end
end
