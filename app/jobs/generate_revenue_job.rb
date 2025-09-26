# frozen_string_literal: true

# app/jobs/generate_revenue_job.rb
# Generates revenue statistics for a given period date.
class GenerateRevenueJob < ApplicationJob
  queue_as :default

  def perform(period_date = Date.today)
    period_date = Date.parse(period_date) if period_date.is_a?(String)
    Rails.logger.info "[GenerateRevenueJob] Generating revenue for #{period_date.strftime('%B %Y')}"
    Statistics::RevenueService.generate_for_date(period_date)
    Rails.logger.info "[GenerateRevenueJob] Revenue generation completed for #{period_date.strftime('%B %Y')}"
  end
end
