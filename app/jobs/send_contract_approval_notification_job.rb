# app/jobs/send_contract_approval_notification_job.rb

class SendContractApprovalNotificationJob < ApplicationJob
  queue_as :default

  # This job is fire-and-forget; opt in to swallow unhandled exceptions
  self.swallow_exceptions = true

  def perform(contract)
    contract = if contract.is_a?(Contract) || contract.respond_to?(:id)
                 contract
               else
                 Contract.find_by(id: contract)
               end

    return if contract.nil? || (contract.respond_to?(:blank?) && contract.blank?)

    Rails.logger.info "[SendContractApprovalNotificationJob] Sending approval notification for contract_id=#{contract.id}"
    Notifications::ContractApprovalEmailService.new(contract).call
    Rails.logger.info "[SendContractApprovalNotificationJob] Sent approval notification for contract_id=#{contract.id}"
  end
end
