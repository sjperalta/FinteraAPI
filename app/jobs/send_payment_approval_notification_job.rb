# frozen_string_literal: true

# app/jobs/send_payment_approval_notification_job.rb
# Sends an email notification to the user when a payment is approved.
class SendPaymentApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    Rails.logger.info "[SendPaymentApprovalNotificationJob] Looking up payment_id=#{payment_id}"
    payment = Payment.find(payment_id)

    Notifications::PaymentApprovedEmailService.new(payment).call
    Rails.logger.info "[SendPaymentApprovalNotificationJob] Notification sent for payment_id=#{payment_id}"
  end
end
