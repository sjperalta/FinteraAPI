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
        current_month = params[:current_month].present? ? params[:current_month].to_i : Date.current.month
        service = Statistics::RevenueFlowService.new(year: params[:year]&.to_i, current_month:)
        payload = service.call
        render json: payload, status: :ok
      rescue ArgumentError
        render json: { error: 'Invalid year' }, status: :bad_request
      end

      # POST /statistics/refresh
      # Enqueues the statistics generation service to run asynchronously
      def refresh
        GenerateStatisticsJob.perform_later(params[:date])
        GenerateRevenueJob.perform_later(params[:date])
        UpdateCreditScoresForAllUsersJob.perform_later
        UpdateOverdueInterestJob.perform_later
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
          on_time_payment
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
          payment_capital_repayment: 0.0,
          on_time_payment: 0.0
        }
      end
    end
  end
end
