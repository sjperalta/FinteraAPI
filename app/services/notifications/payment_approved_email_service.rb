# app/services/notifications/payment_approved_email_service.rb

module Notifications
  class PaymentApprovedEmailService
    def initialize(payment)
      @payment = payment
      @user = @payment.contract.applicant_user  # El usuario que realizó la solicitud del contrato
    end

    def call
      send_payment_approval_email
    end

    private

    # Método para enviar el correo de notificación de pago aprobado
    def send_payment_approval_email
      UserMailer.with(user: @user, payment: @payment).payment_approved.deliver_now
    end
  end
end
