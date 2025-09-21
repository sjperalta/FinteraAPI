# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyAdminPaymentReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment)
    payment = Payment.find_by(id: payment)
    Rails.logger.info "[NotifyAdminPaymentReceiptJob] Notifying admins for payment_id=#{payment&.id}"
    return unless payment

    begin
      Notifications::AdminPaymentReceiptNotificationService.new(payment).call
      Rails.logger.info "[NotifyAdminPaymentReceiptJob] Notified admins for payment_id=#{payment.id}"
    rescue StandardError => e
      Rails.logger.error "[NotifyAdminPaymentReceiptJob] Error notifying admins for payment_id=#{payment.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end

  private

  def send_admin_notification_email
    # kept for backward compatibility
  end
end
