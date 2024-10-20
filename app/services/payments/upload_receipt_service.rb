# app/services/payments/upload_receipt_service.rb

module Payments
  class UploadReceiptService
    def initialize(payment:, receipt:)
      @payment = payment
      @receipt = receipt
    end

    def call
      @payment.transaction do
        upload_receipt
        notify_admin
      end
      true
    rescue => e
      Rails.logger.error("Error subiendo el comprobante: #{e.message}")
      false
    end

    private

    def upload_receipt
      @payment.document.attach(@receipt)
      @payment.update!(status: 'pending')
    end

    def notify_admin
      NotifyAdminPaymentReceiptJob.perform_later(@payment)  # Colocamos la tarea en la cola para ejecutarla en segundo plano
    end
  end
end
