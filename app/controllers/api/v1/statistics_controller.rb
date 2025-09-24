# frozen_string_literal: true

module Api
  module V1
    class StatisticsController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource

      def index
        # Extract month and year from query parameters and normalize to integers (or nil)
        month = params[:month].present? ? params[:month].to_i : nil
        year  = params[:year].present? ? params[:year].to_i : nil

        # Call the service with the provided parameters (or default values)
        statistic = Statistics::FetchMonthStatisticsService.call(month: month, year: year)

        # if statistic is nil then return dummy response with zeros
        if statistic.blank?
          render json: {
            total_income: 0,
            total_income_growth: 0,
            total_interest: 0,
            total_interest_growth: 0,
            new_customers: 0,
            new_customers_growth: 0
          }, status: :ok
          return
        end

        # Return a focused JSON payload including the newly computed fields
        render json: statistic.as_json(only: %i[
          id
          period_date
          total_income
          total_interest
          payment_reserve
          payment_down_payment
          payment_installments
          on_time_payment
          delayed_payment
          new_customers
          created_at
          updated_at
        ]), status: :ok
      end

      def revenue_flow
        year = params[:year].present? ? params[:year].to_i : Date.current.year
        current_month = Date.current.month

        if year < 2000 || year > Date.today.year
          render json: { error: 'Invalid year' }, status: :bad_request
          return
        end

        # Base colors for light and dark themes
        light_base_color = "rgba(237, 242, 247, 1)"
        dark_base_color = "rgba(42, 49, 60, 1)"

        # Accent colors for each payment type
        colors = {
          'reservation' => "rgba(250, 204, 21, 1)",  # yellow/warning
          'down_payment' => "rgba(74, 222, 128, 1)", # green/success
          'installment' => "rgba(255, 120, 75, 1)"   # orange
        }

        # Build datasets for light and dark themes
        datasets_light = []
        datasets_dark = []

        %w[reservation down_payment installment].each_with_index do |payment_type, index|
          # Get monthly data for this payment type
          monthly_data = (1..12).map do |month|
            Revenue.find_by(payment_type: payment_type, year: year, month: month)&.amount || 0.0
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
          year: year,
          current_month: current_month,
          datasets_light: datasets_light,
          datasets_dark: datasets_dark,
          labels: %w[Jan Feb Mar April May Jun July Aug Sep Oct Nov Dec]
        }, status: :ok
      end
    end
  end
end
