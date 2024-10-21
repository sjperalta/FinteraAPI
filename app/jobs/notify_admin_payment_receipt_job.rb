# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyAdminPaymentReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment)
    @payment = payment
    # Llamamos al servicio que notifica al administrador
    send_admin_notification_email
  end

  private

  def send_admin_notification_email
    Notifications::AdminPaymentReceiptNotificationService.new(@payment).call
  end
end
