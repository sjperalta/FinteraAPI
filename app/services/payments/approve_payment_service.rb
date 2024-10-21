module Payments
  class ApprovePaymentService
    def initialize(payment:)
      @payment = payment
    end

    #TODO: deberia de retornar un {success: true, message: 'sdsd'}
    def call
      return false unless can_approve_payment?

      @payment.transaction do
        @payment.approve!  # Cambia el estado del pago a 'approved'
        update_balance  # Actualiza el saldo del contrato asociado
        send_approval_notification  # Enviar notificación
      end
      true
    rescue => e
      error_message = "Error aprobando el pago: #{e.message}"
      Rails.logger.error(error_message)
      false
    end

    private

    # Verificar si el pago puede ser aprobado (por ejemplo, si ya está aprobado o rechazado)
    def can_approve_payment?
      unless @payment.pending?
        Rails.logger.error("Pago con ID #{@payment.id} no puede ser aprobado, ya tiene el estado #{@payment.status}")
        return false
      end
      true
    end

    # Actualiza el saldo pendiente del contrato asociado
    def update_balance
      @payment.contract.update_balance(@payment.amount)
    end

    # Enviar notificación al usuario de que el pago fue aprobado
    def send_approval_notification
      SendPaymentApprovalNotificationJob.perform_later(@payment.id)  # Coloca el trabajo en la cola de jobs
    end
  end
end
