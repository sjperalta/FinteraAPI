module Statistics
  class GenerateStatisticsService
    def initialize(period_date = Date.today)
      @period_date = parse_date(period_date)
    end

    def call
      statistic = Statistic.find_or_initialize_by(period_date: @period_date.beginning_of_month)

      begin
        payments_data = calculate_payments
        statistic.assign_attributes(
          total_income: payments_data[:total_income],
          total_interest: payments_data[:total_interest],
          new_customers: calculate_new_customers
        )
        statistic.save!

        notify_admin_async
      rescue StandardError => e
        Rails.logger.error("Error generating statistics: #{e.message}")
      end
    end

    private

    def parse_date(date)
      return date if date.is_a?(Date)  # If already a Date object, return it
      Date.parse(date) rescue Date.today  # Try to parse, fallback to today if error
    end

    def period_range
      @period_date.beginning_of_month..@period_date.end_of_month
    end

    def calculate_payments
      result = Payment.where(approved_at: period_range)
                      .pluck(Arel.sql("SUM(amount) AS total_income, SUM(interest_amount) AS total_interest"))
                      .first
      { total_income: result[0] || 0, total_interest: result[1] || 0 }
    end

    def calculate_new_customers
      User.where(created_at: period_range, role: 'user').count
    end

    def notify_admin_async
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
