# frozen_string_literal: true

module Statistics
  # Service to generate monthly statistics
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
          payment_reserve: payments_data[:payment_reserve],
          payment_installments: payments_data[:payment_installments],
          payment_down_payment: payments_data[:payment_down_payment],
          on_time_payment: payments_data[:on_time_payment],
          delayed_payment: payments_data[:delayed_payment],
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
      return date if date.is_a?(Date) # If already a Date object, return it

      begin
        Date.parse(date)
      rescue StandardError
        Date.today
      end
    end

    def period_range
      @period_date.beginning_of_month..@period_date.end_of_month
    end

    def calculate_payments
      payments = Payment.where(approved_at: period_range)
      totals = payments.pluck(Arel.sql('SUM(amount) AS total_income, SUM(interest_amount) AS total_interest')).first

      # Breakdown by payment_type
      reserve_total = payments.where(payment_type: 'reservation').sum(:amount) || 0
      down_payment_total = payments.where(payment_type: 'down_payment').sum(:amount) || 0
      installments_total = payments.where(payment_type: 'installment').sum(:amount) || 0

      # On-time vs delayed (approved_at <= due_date considered on-time)
      on_time_total = payments.where('approved_at <= due_date').sum(:amount) || 0
      delayed_total = payments.where('approved_at > due_date').sum(:amount) || 0

      {
        total_income: totals[0] || 0,
        total_interest: totals[1] || 0,
        payment_reserve: reserve_total,
        payment_down_payment: down_payment_total,
        payment_installments: installments_total,
        on_time_payment: on_time_total,
        delayed_payment: delayed_total
      }
    end

    def calculate_new_customers
      User.where(created_at: period_range, role: 'user').count
    end

    def notify_admin_async
      users = User.where(role: 'admin')
      users.each do |user|
        Notification.create!(
          user:,
          title: 'Actualizacion de estadisticas',
          message: 'Se ha ejecutado el servicio de actualizacion de estadisticas.',
          notification_type: 'generate_statistics'
        )
      rescue StandardError => e
        Rails.logger.error("Failed to create statistics notification for user #{user.id}: #{e.message}")
      end
    end
  end
end
