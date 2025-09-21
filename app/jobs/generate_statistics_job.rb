class GenerateStatisticsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 3 # Retry up to 3 times

  def perform(period_date = Date.today)
    Rails.logger.info "[GenerateStatisticsJob] Starting for period_date=#{period_date}"
    begin
      Statistics::GenerateStatisticsService.new(period_date).call
      Rails.logger.info "[GenerateStatisticsJob] Completed for period_date=#{period_date}"
    rescue StandardError => e
      Rails.logger.error "[GenerateStatisticsJob] Failed for period_date=#{period_date}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
