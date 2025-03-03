# app/jobs/release_unpaid_reservation_job.rb

class ReleaseUnpaidReservationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 2

  def perform
    Rails.logger.info "Starting ReleaseUnpaidReservationJob"
    Contracts::ReleaseUnpaidReservationService.new.call
    Rails.logger.info "Completed ReleaseUnpaidReservationJob"
  rescue StandardError => e
    Rails.logger.error "ReleaseUnpaidReservationJob failed: #{e.message}"
    raise e
  end
end
