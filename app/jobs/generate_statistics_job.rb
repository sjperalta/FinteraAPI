class GenerateStatisticsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 3 # Retry up to 3 times

  def perform(period_date = Date.today)
    Rails.logger.info "Starting GenerateStatisticsJob for #{period_date}"
    Statistics::GenerateStatisticsService.new(period_date).call
    Rails.logger.info "Completed GenerateStatisticsJob for #{period_date}"
  rescue StandardError => e
    Rails.logger.error "GenerateStatisticsJob failed for #{period_date}: #{e.message}"
    raise e
  end
end
