module Reservations
  class CreateReservationRequestService
    def initialize(lot_id:, payment_term:, financing_type:, user:, documents:)
      @lot_id = lot_id
      @payment_term = payment_term
      @financing_type = financing_type  # ahora acepta direct, bank, o cash
      @user = user
      @documents = documents
    end

    def call
      reservation_request = ReservationRequest.new(
        lot_id: @lot_id,
        payment_term: @payment_term,
        financing_type: @financing_type,
        status: 'pending',
        user: @user
      )

      # Adjuntar documentos si se proporcionaron
      if @documents.present?
        @documents.each { |doc| reservation_request.documents.attach(doc) }
      end

      if reservation_request.save
        { success: true, reservation: reservation_request }
      else
        { success: false, errors: reservation_request.errors.full_messages }
      end
    end
  end
end
