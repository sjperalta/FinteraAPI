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
    # Prefer an actual Contract instance
    return input if input.is_a?(Contract)

    # If the input is nil, return nil
    return nil if input.nil?

    # If input looks like an id (Integer or String numeric), try to find by id
    if input.is_a?(Integer) || (input.is_a?(String) && input =~ /^\d+$/)
      return Contract.find_by(id: input.to_i)
    end

    # For other objects, accept objects that explicitly look like a contract (responds to :id and not a primitive)
    return input if input.respond_to?(:id)

    nil
  end

  def safe_contract_id(contract)
    contract.respond_to?(:id) ? contract.id : 'unknown'
  end
end
