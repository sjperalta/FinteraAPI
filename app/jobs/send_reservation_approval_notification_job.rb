# app/jobs/send_reservation_approval_notification_job.rb

class SendReservationApprovalNotificationJob < ApplicationJob
  queue_as :default

  def perform(contract)
    return if contract.blank?

    Notifications::ReservationApprovalEmailService.new(contract).call
  end
end
