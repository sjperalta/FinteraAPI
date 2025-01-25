class GenerateRevenueJob < ApplicationJob
  queue_as :default

  def perform
    # Generate and store revenue for the current month
    Statistics::RevenueService.generate_for_current_month
  end
end
