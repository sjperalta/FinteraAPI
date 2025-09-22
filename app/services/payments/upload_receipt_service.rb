# frozen_string_literal: true

module Payments
  class UploadReceiptService
    include Notifiable

    def initialize(payment:, receipt:, user:)
      @payment = payment
      @receipt = receipt
      @user = user
    end

    def call
      # Check if the user is allowed to upload the receipt
      check_if_can_upload

      @payment.transaction do
        upload_receipt
        send_notification
      end

      notify_admin

      true
    rescue StandardError => e
      Rails.logger.error("Error subiendo el comprobante: #{e.message}")
      false
    end

    private

    # Validate if the user can upload the receipt
    def check_if_can_upload
      unless @user.id == @payment.contract.applicant_user_id
        raise 'El usuario no está autorizado para subir este comprobante.'
      end

      return unless @payment.status == 'paid'

      raise 'Este pago ya ha sido completado y no se pueden subir más comprobantes.'
    end

    # Attach the receipt file and update the payment status
    def upload_receipt
      @payment.document.attach(@receipt)
      @payment.update!(status: 'submitted', payment_date: Date.today)
    end

    def send_notification
      notify_admins(
        title: 'Pago Actualizado',
        message: "Has recibido un pago por #{@payment.amount}, Contrato ##{@payment.contract.id}",
        notification_type: 'payment_upload'
      )
    end

    # Notify admins about the uploaded receipt
    def notify_admin
      NotifyAdminPaymentReceiptJob.perform_later(@payment)
    end
  end
end
