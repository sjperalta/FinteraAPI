# frozen_string_literal: true

# app/jobs/generate_statistics_job.rb
# Generates statistics for a given period by calling the Statistics::GenerateStatisticsService.
class GenerateStatisticsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(period_date = Date.today)
    Rails.logger.info "[GenerateStatisticsJob] Starting for period_date=#{period_date}"
    Statistics::GenerateStatisticsService.new(period_date).call
    Rails.logger.info "[GenerateStatisticsJob] Completed for period_date=#{period_date}"
  end
end
