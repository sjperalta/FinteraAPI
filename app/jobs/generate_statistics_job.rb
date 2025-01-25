class GenerateStatisticsJob < ApplicationJob
  queue_as :default

  def perform(period_date = Date.today)
    # Call the service to generate statistics
    Statistics::GenerateStatisticsService.new(period_date).call
  end
end
