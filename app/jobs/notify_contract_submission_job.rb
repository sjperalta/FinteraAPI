# frozen_string_literal: true

# app/jobs/notify_admin_payment_receipt_job.rb
# Notifies admins when a payment is received by calling the Notifications::AdminPaymentReceiptNotificationService.
class NotifyContractSubmissionJob < ApplicationJob
  queue_as :default

  def perform(contract)
    contract = Contract.find_by(id: contract)
    Rails.logger.info "[NotifyContractSubmissionJob] Notifying contract submission contract_id=#{contract&.id}"
    return unless contract

    Notifications::ContractSubmissionEmailService.new(contract).call
    Rails.logger.info "[NotifyContractSubmissionJob] Notification sent for contract_id=#{contract.id}"
  end
end
