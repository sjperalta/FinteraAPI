# app/jobs/send_contract_approval_notification_job.rb

class SendContractApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    Notifications::ContractApprovalEmailService.new(contract).call
  end
end
