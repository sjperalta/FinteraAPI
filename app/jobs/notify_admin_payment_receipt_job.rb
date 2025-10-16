# frozen_string_literal: true

# app/jobs/notify_admin_payment_receipt_job.rb
# Notifies admins when a payment is received by calling the Notifications::AdminPaymentReceiptNotificationService.
class NotifyAdminPaymentReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment)
    payment = Payment.find_by(id: payment)
    return unless payment

    Notifications::AdminPaymentReceiptNotificationService.new(payment).call
    Rails.logger.info "[NotifyAdminPaymentReceiptJob] Notified admins for payment_id=#{payment.id}"
  end
end
