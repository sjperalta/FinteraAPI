# app/jobs/send_contract_approval_notification_job.rb

class SendContractApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    return if contract.blank?

    Notifications::ContractApprovalEmailService.new(contract).call
  end
end
