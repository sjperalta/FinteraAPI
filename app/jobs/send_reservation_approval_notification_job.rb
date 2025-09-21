# app/jobs/send_reservation_approval_notification_job.rb

class SendReservationApprovalNotificationJob < ApplicationJob
  queue_as :default

  # fire-and-forget style
  self.swallow_exceptions = true

  def perform(contract)
    contract = normalize_contract(contract)
    return if contract.nil?

    Rails.logger.info "[SendReservationApprovalNotificationJob] Sending reservation approval for contract_id=#{safe_contract_id(contract)}"
    Notifications::ReservationApprovalEmailService.new(contract).call
    Rails.logger.info "[SendReservationApprovalNotificationJob] Sent reservation approval for contract_id=#{safe_contract_id(contract)}"
  end

  private

  def normalize_contract(input)
    return input if input.is_a?(Contract)
    return nil if input.nil?
    if input.is_a?(Integer) || (input.is_a?(String) && /^\d+$/.match?(input))
      return Contract.find_by(id: input.to_i)
    end
    return input if input.respond_to?(:id)
    nil
  end

  def safe_contract_id(contract)
    contract.respond_to?(:id) ? contract.id : "unknown"
  end
end
