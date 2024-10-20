# app/services/payments/reject_payment_service.rb

module Payments
  class RejectPaymentService
    def initialize(payment:)
      @payment = payment
    end

    def call
      if @payment.update(status: 'rejected')
        # Aquí podrías enviar una notificación si es necesario
        true
      else
        false
      end
    rescue => e
      Rails.logger.error("Error rechazando el pago: #{e.message}")
      false
    end
  end
end
