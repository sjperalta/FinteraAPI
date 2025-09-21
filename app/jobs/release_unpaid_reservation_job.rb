# app/jobs/release_unpaid_reservation_job.rb

class ReleaseUnpaidReservationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 2

  def perform
    Rails.logger.info "[ReleaseUnpaidReservationJob] Starting"
    begin
      Contracts::ReleaseUnpaidReservationService.new.call
      Rails.logger.info "[ReleaseUnpaidReservationJob] Completed"
    rescue StandardError => e
      Rails.logger.error "[ReleaseUnpaidReservationJob] Failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
