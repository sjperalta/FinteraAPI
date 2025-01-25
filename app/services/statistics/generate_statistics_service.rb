# app/services/statistics/generate_statistics_service.rb

module Statistics
  class GenerateStatisticsService
    def initialize(period_date = Date.today)
      @period_date = period_date
    end

    def call
      total_income = calculate_total_income
      total_interest = calculate_total_interest
      new_customers = calculate_new_customers

      Statistic.find_or_initialize_by(period_date: @period_date.beginning_of_month).tap do |stat|
        stat.total_income = total_income
        stat.total_interest = total_interest
        stat.new_customers = new_customers
        stat.save!
      end

      notify_admin
    end

    private

    # Helper method to determine the start and end of the month
    def period_range
      @period_date.beginning_of_month..@period_date.end_of_month
    end

    def calculate_total_income
      # Sum all payments (filtered by the monthly period range)
      Payment.where(approved_at: period_range).sum(:amount)
    end

    def calculate_total_interest
      # Sum all interest payments (filtered by the monthly period range)
      Payment.where(approved_at: period_range).sum(:interest_amount)
    end

    def calculate_new_customers
      # Count customers created within the monthly period
      User.where(created_at: period_range, role: 'user').count
    end

    def notify_admin
      users = User.where(role: 'admin')
      users.each do |user|
        Notification.create(
          user: user,
          title: "Actualizacion de estadisticas",
          message: "Se ha ejecutado el servicio de actualizacion de estadisticas.",
          notification_type: "generate_statistics"
        )
      end
    end
  end
end
