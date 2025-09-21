class GenerateRevenueJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[GenerateRevenueJob] Generating revenue for current month"
    Statistics::RevenueService.generate_for_current_month
    Rails.logger.info "[GenerateRevenueJob] Revenue generation completed"
  end
end
