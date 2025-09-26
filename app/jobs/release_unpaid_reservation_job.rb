# frozen_string_literal: true

# app/jobs/release_unpaid_reservation_job.rb
# Releases unpaid reservations by calling the Contracts::ReleaseUnpaidReservationService.
class ReleaseUnpaidReservationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 2

  def perform
    Rails.logger.info '[ReleaseUnpaidReservationJob] Starting'
    Contracts::ReleaseUnpaidReservationService.new.call
    Rails.logger.info '[ReleaseUnpaidReservationJob] Completed'
  end
end
