# app/services/reservations/reject_reservation_service.rb

module Reservations
  class RejectReservationService
    def initialize(reservation:)
      @reservation = reservation
    end

    def call
      if @reservation.update(status: 'rejected')
        { success: true, message: 'Solicitud rechazada' }
      else
        { success: false, errors: @reservation.errors.full_messages }
      end
    end
  end
end
