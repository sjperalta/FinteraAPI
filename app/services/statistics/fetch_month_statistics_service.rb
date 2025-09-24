# frozen_string_literal: true

module Statistics
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
      current_stat = Statistic.find_by(period_date: period_date)

      # Fetch the statistics record for the previous month (used to compute growths)
      previous_period = period_date.prev_month.beginning_of_month
      previous_stat = Statistic.find_by(period_date: previous_period)

      # Calculate growth percentages (useful for logging or clients that call separately)
      total_income_growth = calculate_growth(current_stat&.total_income || 0, previous_stat&.total_income || 0)
      total_interest_growth = calculate_growth(current_stat&.total_interest || 0, previous_stat&.total_interest || 0)
      new_customers_growth = calculate_growth(current_stat&.new_customers || 0, previous_stat&.new_customers || 0)

      # Attach growth values to the record as virtual attributes for downstream consumption if needed
      if current_stat
        current_stat.define_singleton_method(:total_income_growth) { total_income_growth }
        current_stat.define_singleton_method(:total_interest_growth) { total_interest_growth }
        current_stat.define_singleton_method(:new_customers_growth) { new_customers_growth }
      end

      # Return the Statistic record (or nil). Controller will handle rendering.
      current_stat
    rescue StandardError => e
      Rails.logger.error "Error fetching statistics for month=#{month}, year=#{year}: #{e.message}"
      {
        total_income: 0,
        total_income_growth: 0,
        total_interest: 0,
        total_interest_growth: 0,
        new_customers: 0,
        new_customers_growth: 0
      }
    end

    # Calculates the percentage growth between the current and previous values.
    # If the previous value is 0 or nil, it returns 0.
    def self.calculate_growth(current, previous)
      if previous.present? && previous.positive?
        (((current.to_f - previous.to_f) / previous.to_f) * 100).round(2)
      else
        0
      end
    end
  end
end
