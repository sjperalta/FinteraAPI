# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyContractSubmissionJob < ApplicationJob
  queue_as :default

  def perform(contract)
    contract = Contract.find_by(id: contract)
    Rails.logger.info "[NotifyContractSubmissionJob] Notifying contract submission contract_id=#{contract&.id}"
    return unless contract

    begin
      Notifications::ContractSubmissionEmailService.new(contract).call
      Rails.logger.info "[NotifyContractSubmissionJob] Notification sent for contract_id=#{contract.id}"
    rescue StandardError => e
      Rails.logger.error "[NotifyContractSubmissionJob] Error notifying contract submission contract_id=#{contract.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
