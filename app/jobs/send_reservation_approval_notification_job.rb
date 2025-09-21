# app/jobs/send_reservation_approval_notification_job.rb

class SendReservationApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    contract = normalize_contract(contract)
    return if contract.nil?

    Rails.logger.info "[SendReservationApprovalNotificationJob] Sending reservation approval for contract_id=#{safe_contract_id(contract)}"
    begin
      Notifications::ReservationApprovalEmailService.new(contract).call
      Rails.logger.info "[SendReservationApprovalNotificationJob] Sent reservation approval for contract_id=#{safe_contract_id(contract)}"
    rescue StandardError => e
      Rails.logger.error "[SendReservationApprovalNotificationJob] Error for contract_id=#{safe_contract_id(contract)}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      # swallow notification errors
    end
  end

  private

  def normalize_contract(input)
    # Accept a Contract instance or a contract-like object (responds to :id)
    return input if input.is_a?(Contract) || input.respond_to?(:id)

    # Otherwise try to find by id (returns nil when not found)
    Contract.find_by(id: input)
  end

  def safe_contract_id(contract)
    contract.respond_to?(:id) ? contract.id : 'unknown'
  end
end
