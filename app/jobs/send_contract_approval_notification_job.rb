# app/jobs/send_contract_approval_notification_job.rb

class SendContractApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    # Accept a Contract instance, a contract-like object (e.g. test double with `id`), or an id.
    contract = if contract.is_a?(Contract) || contract.respond_to?(:id)
                 contract
               else
                 Contract.find_by(id: contract)
               end

    # If contract is nil or explicitly blank, return early. Guard `blank?` in case a double doesn't implement it.
    return if contract.nil? || (contract.respond_to?(:blank?) && contract.blank?)

    Rails.logger.info "[SendContractApprovalNotificationJob] Sending approval notification for contract_id=#{contract.id}"
    begin
      Notifications::ContractApprovalEmailService.new(contract).call
      Rails.logger.info "[SendContractApprovalNotificationJob] Sent approval notification for contract_id=#{contract.id}"
    rescue StandardError => e
      Rails.logger.error "[SendContractApprovalNotificationJob] Error sending approval notification for contract_id=#{contract.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      # swallow notification failures to avoid retries
    end
  end
end
