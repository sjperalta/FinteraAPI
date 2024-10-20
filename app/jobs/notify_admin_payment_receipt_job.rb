# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyAdminPaymentReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment)
    @payment = payment
    @contract = @payment.contract
    # Llamamos al servicio que notifica al administrador
    send_admin_notification_email
  end

  private

  def send_admin_notification_email
    AdminMailer.with(payment: @payment, contract: @contract).payment_receipt_uploaded.deliver_now
  end
end
