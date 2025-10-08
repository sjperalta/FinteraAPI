# frozen_string_literal: true

module Statistics
  # Service object to build revenue flow datasets for charts
  class RevenueFlowService
    DEFAULT_YEAR_RANGE = (2020..Date.today.year)

    attr_reader :year, :current_month

    def initialize(year: nil, current_month: nil)
      @year = year || Date.current.year
      @current_month = current_month || Date.current.month
    end

    def call
      validate_year!

      build_response
    end

    private

    def validate_year!
      return if DEFAULT_YEAR_RANGE.cover?(year)

      raise ArgumentError, 'Invalid year'
    end

    def colors
      {
        'reservation' => 'rgba(250, 204, 21, 1)',
        'down_payment' => 'rgba(74, 222, 128, 1)',
        'installment' => 'rgba(255, 120, 75, 1)',
        'prepayment' => 'rgba(59, 130, 246, 1)'
      }
    end

    def label_map
      {
        'reservation' => 'Reserva',
        'down_payment' => 'Prima',
        'installment' => 'Cuotas',
        'prepayment' => 'Abonos a Capital'
      }
    end

    def payment_types
      %w[reservation down_payment installment prepayment]
    end

    def base_colors
      {
        light: 'rgba(237, 242, 247, 1)',
        dark: 'rgba(42, 49, 60, 1)'
      }
    end

    def build_monthly_data(payment_type)
      (1..12).map do |m|
        rec = Revenue.find_by(payment_type:, year:, month: m)
        (rec&.amount || 0.0).to_f
      end
    end

    def build_backgrounds(payment_type)
      light = (1..12).map { |m| m == current_month ? colors[payment_type] : base_colors[:light] }
      dark  = (1..12).map { |m| m == current_month ? colors[payment_type] : base_colors[:dark] }
      [light, dark]
    end

    def common_dataset_opts(payment_type, monthly_data)
      {
        label: label_map[payment_type],
        data: monthly_data,
        borderWidth: 1,
        borderRadius: 5,
        borderSkipped: false,
        tension: 0.3,
        fill: false,
        pointRadius: 0,
        pointHoverRadius: 0,
        pointHitRadius: 10,
        pointHoverBorderWidth: 0,
        pointHoverBorderColor: 'transparent',
        # Rendering hints to reduce spacing so data labels sit closer to bars
        barPercentage: 0.8,
        categoryPercentage: 0.9,
        maxBarThickness: 50,
        datalabels: {
          anchor: 'end',
          align: 'end',
          offset: -6
        }
      }
    end

    def build_response
      datasets_light = []
      datasets_dark = []

      payment_types.each do |payment_type|
        monthly_data = build_monthly_data(payment_type)
        light_bg, dark_bg = build_backgrounds(payment_type)

        opts = common_dataset_opts(payment_type, monthly_data)
        datasets_light << opts.merge(backgroundColor: light_bg)
        datasets_dark  << opts.merge(backgroundColor: dark_bg)
      end

      {
        year:,
        current_month:,
        datasets_light:,
        datasets_dark:,
        labels: %w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic]
      }
    end
  end
end
