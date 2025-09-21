# app/jobs/send_payment_approval_notification_job.rb

class SendPaymentApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    Rails.logger.info "[SendPaymentApprovalNotificationJob] Looking up payment_id=#{payment_id}"
    # Use `find` so callers/tests expecting ActiveRecord::RecordNotFound get the exception
    payment = Payment.find(payment_id)

    begin
      Notifications::PaymentApprovedEmailService.new(payment).call
      Rails.logger.info "[SendPaymentApprovalNotificationJob] Notification sent for payment_id=#{payment_id}"
    rescue StandardError => e
      Rails.logger.error "[SendPaymentApprovalNotificationJob] Error sending notification for payment_id=#{payment_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      # swallow to avoid retry storms for notification failures
    end
  end
end
