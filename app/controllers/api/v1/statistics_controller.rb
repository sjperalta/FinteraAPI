# frozen_string_literal: true

module Api
  module V1
    # Controller for managing statistics
    class StatisticsController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource

      # GET /statistics
      def index
        # Call the service with the provided parameters (or default values)
        statistic = Statistics::FetchMonthStatisticsService.call(month: params[:month], year: params[:year])

        # if statistic is nil then return dummy response with zeros
        if statistic.blank?
          render json: dummy_statistics_response, status: :ok
          return
        end

        # Return a focused JSON payload including the newly computed fields
        render json: statistic.as_json(only: statistic_json_fields), status: :ok
      end

      # Graph data for revenue flow by payment type
      def revenue_flow
        year = params[:year].present? ? params[:year].to_i : Date.current.year
        current_month = Date.current.month

        if year < 2020 || year > Date.today.year
          render json: { error: 'Invalid year' }, status: :bad_request
          return
        end

        # Base colors for light and dark themes
        light_base_color = 'rgba(237, 242, 247, 1)'
        dark_base_color = 'rgba(42, 49, 60, 1)'

        # Accent colors for each payment type
        colors = {
          'reservation' => 'rgba(250, 204, 21, 1)',  # yellow/warning
          'down_payment' => 'rgba(74, 222, 128, 1)', # green/success
          'installment' => 'rgba(255, 120, 75, 1)'   # orange
        }

        # Build datasets for light and dark themes
        datasets_light = []
        datasets_dark = []

        %w[reservation down_payment installment].each_with_index do |payment_type, _index|
          # Get monthly data for this payment type
          monthly_data = (1..12).map do |m|
            rec = Revenue.find_by(payment_type:, year:, month: m)
            # Ensure we serialize numbers (not strings) by converting to float
            (rec&.amount || 0.0).to_f
          end

          # Create background colors array - highlight current month
          light_backgrounds = (1..12).map do |month|
            month == current_month ? colors[payment_type] : light_base_color
          end

          dark_backgrounds = (1..12).map do |month|
            month == current_month ? colors[payment_type] : dark_base_color
          end

          # Dataset labels
          label_map = {
            'reservation' => 'Reserva',
            'down_payment' => 'Prima',
            'installment' => 'Cuotas'
          }

          # Light theme dataset
          datasets_light << {
            label: label_map[payment_type],
            data: monthly_data,
            backgroundColor: light_backgrounds,
            borderWidth: 0,
            borderRadius: 5
          }

          # Dark theme dataset
          datasets_dark << {
            label: label_map[payment_type],
            data: monthly_data,
            backgroundColor: dark_backgrounds,
            borderWidth: 0,
            borderRadius: 5
          }
        end

        render json: {
          year:,
          current_month:,
          datasets_light:,
          datasets_dark:,
          labels: %w[Jan Feb Mar April May Jun July Aug Sep Oct Nov Dec]
        }, status: :ok
      end

      # POST /statistics/refresh
      # Enqueues the statistics generation service to run asynchronously
      def refresh
        GenerateStatisticsJob.perform_later(params[:date])
        GenerateRevenueJob.perform_later(params[:date])
        render json: { message: 'Servicio de Estadísticas iniciado' }, status: :ok
      rescue StandardError => e
        Rails.logger.error("Statistics refresh error: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: 'An unexpected error occurred while starting statistics generation' },
               status: :internal_server_error
      end

      private

      def statistic_json_fields
        %i[
          total_income
          total_income_growth
          total_interest
          total_interest_growth
          new_customers
          new_customers_growth
          new_contracts
          new_contracts_growth
          payment_down_payment
          payment_installments
          payment_reserve
          payment_capital_repayment
        ]
      end

      def dummy_statistics_response
        {
          total_income: 0.0,
          total_income_growth: 0.0,
          total_interest: 0.0,
          total_interest_growth: 0.0,
          new_customers: 0,
          new_customers_growth: 0.0,
          new_contracts: 0,
          new_contracts_growth: 0.0,
          payment_down_payment: 0.0,
          payment_installments: 0.0,
          payment_reserve: 0.0,
          payment_capital_repayment: 0.0
        }
      end
    end
  end
end
