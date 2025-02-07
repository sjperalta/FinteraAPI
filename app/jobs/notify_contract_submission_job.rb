# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyContractSubmissionJob < ApplicationJob
  queue_as :default

  def perform(contract)
    Notifications::ContractSubmissionEmailService.new(contract).call
  end
end
