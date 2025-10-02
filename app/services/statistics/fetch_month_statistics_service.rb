# frozen_string_literal: true

module Statistics
  # Service to fetch statistics for a given month and year,
  class FetchMonthStatisticsService
    def self.call(month: nil, year: nil)
      # Determine the period_date based on provided month and year,
      # defaulting to the current month if not provided.
      period_date = if month.present? && year.present?
                      Date.new(year.to_i, month.to_i)
                    else
                      Date.today
                    end.beginning_of_month

      # Fetch the statistics record for the requested month (nil if none)
      Statistic.find_by(period_date:)

      # Return the Statistic record (or nil). Controller will handle rendering.
    rescue StandardError => e
      Rails.logger.error "Error fetching statistics for month=#{month}, year=#{year}: #{e.message}"
      {
        total_income: 0,
        total_income_growth: 0,
        total_interest: 0,
        total_interest_growth: 0,
        new_customers: 0,
        new_customers_growth: 0,
        new_contracts: 0,
        new_contracts_growth: 0,
        payment_down_payment: 0,
        payment_installments: 0,
        payment_reserve: 0
      }
    end
  end
end
