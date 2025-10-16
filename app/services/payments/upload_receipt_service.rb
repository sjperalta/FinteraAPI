# frozen_string_literal: true

module Payments
  # Service to handle the uploading of payment receipts
  class UploadReceiptService
    include Notifiable

    class UploadError < StandardError; end

    attr_reader :payment, :receipt, :user, :paid_amount

    def initialize(payment:, receipt:, user:, paid_amount: nil)
      @payment = payment
      @receipt = receipt
      @user = user
      @paid_amount = paid_amount
    end

    def call
      validate_request!

      ActiveRecord::Base.transaction do
        attach_receipt
        apply_payment_attributes
        submit_payment!
        send_notification
      end

      notify_admin

      success_result
    rescue UploadError => e
      Rails.logger.warn("No se pudo subir el comprobante: #{e.message}")
      failure_result(e.message)
    rescue StandardError => e
      Rails.logger.error("Error subiendo el comprobante: #{e.message}")
      failure_result('Ocurrió un error al subir el comprobante.')
    end

    private

    def validate_request!
      raise UploadError, 'El comprobante es requerido.' unless receipt.present?
      raise UploadError, 'El usuario no está autorizado para subir este comprobante.' unless authorized_user?
      raise UploadError, 'Este pago ya ha sido completado.' if payment.status == 'paid'
    end

    def authorized_user?
      user.id == payment.contract.applicant_user_id || (user.respond_to?(:admin?) && user.admin?)
    end

    def attach_receipt
      payment.document.attach(receipt)
    end

    def apply_payment_attributes
      attributes = { payment_date: Time.zone.today }
      attributes[:paid_amount] = paid_amount if paid_amount.present?
      payment.update!(attributes)
    end

    def submit_payment!
      raise UploadError, 'El pago no se puede enviar en su estado actual.' unless payment.may_submit?

      payment.submit!
    end

    def send_notification
      notify_admins(
        title: 'Pago Actualizado',
        message: "Has recibido un pago por #{payment.amount}, Contrato ##{payment.contract.id}",
        notification_type: 'payment_upload'
      )
    end

    def notify_admin
      NotifyAdminPaymentReceiptJob.perform_later(payment)
    end

    def success_result
      { success: true, payment: }
    end

    def failure_result(error_message)
      { success: false, errors: [error_message] }
    end
  end
end
