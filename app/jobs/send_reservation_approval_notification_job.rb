# app/jobs/send_contract_approval_notification_job.rb

class SendcontractApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract_id)
    contract = contract.find(contract_id)
    Notifications::contractApprovedEmailService.new(contract).call
  end

  private

  def send_admin_notification_email
    AdminMailer.with(payment: @payment, contract: @contract).payment_receipt_uploaded.deliver_now
  end
end
