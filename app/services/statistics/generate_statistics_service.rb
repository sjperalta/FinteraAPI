# frozen_string_literal: true

module Statistics
  # Service to generate monthly statistics
  class GenerateStatisticsService
    def initialize(period_date = Date.today)
      @period_date = parse_date(period_date)
    end

    def call
      ActiveRecord::Base.transaction do
        statistic = Statistic.find_or_initialize_by(period_date: @period_date.beginning_of_month)

        # Consolidate queries into a single CTE
        data = fetch_statistics_data

        growth_data = calculate_growth_data(data)

        statistic.assign_attributes(
          total_income: data[:total_income],
          total_interest: data[:total_interest],
          payment_reserve: data[:payment_reserve],
          payment_installments: data[:payment_installments],
          payment_down_payment: data[:payment_down_payment],
          payment_capital_repayment: data[:payment_capital_repayment],
          on_time_payment: data[:on_time_payment],
          delayed_payment: data[:delayed_payment],
          new_contracts: data[:new_contracts],
          new_customers: data[:new_customers],
          total_income_growth: growth_data[:total_income_growth],
          total_interest_growth: growth_data[:total_interest_growth],
          new_customers_growth: growth_data[:new_customers_growth],
          new_contracts_growth: growth_data[:new_contracts_growth]
        )

        statistic.save!
      end

      # Move notifications outside the transaction
      notify_admin_async
    rescue StandardError => e
      Rails.logger.error("Error generating statistics: #{e.message}")
      raise ActiveRecord::Rollback
    end

    private

    def parse_date(date)
      return date if date.is_a?(Date)

      begin
        Date.parse(date)
      rescue StandardError
        Date.today
      end
    end

    def period_range
      @period_date.beginning_of_month..@period_date.end_of_month
    end

    def fetch_statistics_data
      start_date = period_range.begin.to_time.strftime('%Y-%m-%d %H:%M:%S')
      end_date = period_range.end.to_time.end_of_day.strftime('%Y-%m-%d %H:%M:%S')

      sql = <<~SQL
        WITH ledger_totals AS (
          SELECT
            -- Total income: sum of all payment entries (negative amounts, so we take absolute value)
            COALESCE(ABS(SUM(CASE WHEN entry_type IN ('reservation', 'down_payment', 'installment', 'full', 'advance', 'prepayment') THEN amount ELSE 0 END)), 0) AS total_income,
            -- Total interest: sum of interest entries (positive amounts)
            COALESCE(SUM(CASE WHEN entry_type = 'interest' THEN amount ELSE 0 END), 0) AS total_interest,
            -- Payment reserve: payments for reservation entries
            COALESCE(ABS(SUM(CASE WHEN entry_type = 'reservation' THEN amount ELSE 0 END)), 0) AS payment_reserve,
            -- Payment down payment: payments for prima/down payment entries
            COALESCE(ABS(SUM(CASE WHEN entry_type = 'down_payment' THEN amount ELSE 0 END)), 0) AS payment_down_payment,
            -- Payment installments: payments for cuota/installment entries
            COALESCE(ABS(SUM(CASE WHEN entry_type = 'installment' THEN amount ELSE 0 END)), 0) AS payment_installments,
            -- Payment capital repayment: payments for capital repayment entries
            COALESCE(ABS(SUM(CASE WHEN entry_type = 'prepayment' THEN amount ELSE 0 END)), 0) AS payment_capital_repayment
          FROM contract_ledger_entries
          WHERE entry_date BETWEEN '#{start_date}' AND '#{end_date}'
        ),
        payment_timeliness AS (
          SELECT
            COALESCE(SUM(CASE WHEN p.approved_at <= p.due_date THEN ABS(cle.amount) ELSE 0 END), 0) AS on_time_payment,
            COALESCE(SUM(CASE WHEN p.approved_at > p.due_date THEN ABS(cle.amount) ELSE 0 END), 0) AS delayed_payment
          FROM contract_ledger_entries cle
          JOIN payments p ON cle.payment_id = p.id
          WHERE cle.entry_type IN ('reservation', 'down_payment', 'installment', 'full', 'advance', 'prepayment')
            AND cle.entry_date BETWEEN '#{start_date}' AND '#{end_date}'
        ),
        counts AS (
          SELECT
            (SELECT COUNT(*) FROM users WHERE created_at BETWEEN '#{start_date}' AND '#{end_date}' AND role = 'user') AS new_customers,
            (SELECT COUNT(*) FROM contracts WHERE created_at BETWEEN '#{start_date}' AND '#{end_date}' AND status = 'approved') AS new_contracts
        )
        SELECT * FROM ledger_totals, payment_timeliness, counts
      SQL

      result = ActiveRecord::Base.connection.select_one(sql) || {}

      {
        total_income: result['total_income'].to_f,
        total_interest: result['total_interest'].to_f,
        payment_reserve: result['payment_reserve'].to_f,
        payment_down_payment: result['payment_down_payment'].to_f,
        payment_installments: result['payment_installments'].to_f,
        payment_capital_repayment: result['payment_capital_repayment'].to_f,
        on_time_payment: result['on_time_payment'].to_f,
        delayed_payment: result['delayed_payment'].to_f,
        new_customers: result['new_customers'].to_i,
        new_contracts: result['new_contracts'].to_i
      }
    end

    def calculate_growth_data(data)
      previous_month_date = @period_date.prev_month.beginning_of_month
      previous_statistic = Statistic.find_by(period_date: previous_month_date)

      return default_growth_data unless previous_statistic

      {
        total_income_growth: calculate_percentage_growth(previous_statistic.total_income, data[:total_income]),
        total_interest_growth: calculate_percentage_growth(previous_statistic.total_interest, data[:total_interest]),
        new_customers_growth: calculate_percentage_growth(previous_statistic.new_customers, data[:new_customers]),
        new_contracts_growth: calculate_percentage_growth(previous_statistic.new_contracts, data[:new_contracts])
      }
    end

    def default_growth_data
      {
        total_income_growth: 0.0,
        total_interest_growth: 0.0,
        new_customers_growth: 0.0,
        new_contracts_growth: 0.0
      }
    end

    def calculate_percentage_growth(previous_value, current_value)
      previous = previous_value.to_f
      current = current_value.to_f

      if previous.zero?
        return 0.0 if current.zero?

        current.positive? ? 100.0 : -100.0
      else
        ((current - previous) / previous * 100).round(2)
      end
    end

    def notify_admin_async
      User.admins.find_each do |user|
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
