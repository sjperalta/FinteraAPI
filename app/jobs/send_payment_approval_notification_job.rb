# app/jobs/send_payment_approval_notification_job.rb

class SendPaymentApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment = Payment.find(payment_id)
    Notifications::PaymentApprovedEmailService.new(payment).call
  end
end
