class GenerateRevenueJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[GenerateRevenueJob] Generating revenue for current month"
    begin
      Statistics::RevenueService.generate_for_current_month
      Rails.logger.info "[GenerateRevenueJob] Revenue generation completed"
    rescue StandardError => e
      Rails.logger.error "[GenerateRevenueJob] Error generating revenue: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
