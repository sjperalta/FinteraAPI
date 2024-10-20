# app/services/reservations/approve_reservation_service.rb

module Reservations
  class ApproveReservationService
    def initialize(reservation:)
      @reservation = reservation
    end

    def call
      if @reservation.update(status: 'approved')
        { success: true, message: 'Solicitud aprobada' }
      else
        { success: false, errors: @reservation.errors.full_messages }
      end
    end
  end
end
