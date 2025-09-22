# frozen_string_literal: true

# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyAdminPaymentReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment)
    payment = Payment.find_by(id: payment)
    Rails.logger.info "[NotifyAdminPaymentReceiptJob] Notifying admins for payment_id=#{payment&.id}"
    return unless payment

    Notifications::AdminPaymentReceiptNotificationService.new(payment).call
    Rails.logger.info "[NotifyAdminPaymentReceiptJob] Notified admins for payment_id=#{payment.id}"
  end
end
