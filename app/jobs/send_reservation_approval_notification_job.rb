# app/jobs/send_reservation_approval_notification_job.rb

class SendReservationApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    # Accept a Contract instance, a contract-like object (test double with `id`), or an id.
    contract = if contract.is_a?(Contract) || contract.respond_to?(:id)
                 contract
               else
                 Contract.find_by(id: contract)
               end

    return if contract.nil?
    if !contract.respond_to?(:id) && contract.respond_to?(:blank?)
      return if contract.blank?
    end

    Rails.logger.info "[SendReservationApprovalNotificationJob] Sending reservation approval for contract_id=#{contract.id}"
    begin
      Notifications::ReservationApprovalEmailService.new(contract).call
      Rails.logger.info "[SendReservationApprovalNotificationJob] Sent reservation approval for contract_id=#{contract.id}"
    rescue StandardError => e
      Rails.logger.error "[SendReservationApprovalNotificationJob] Error for contract_id=#{contract.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      # swallow notification errors
    end
  end
end
