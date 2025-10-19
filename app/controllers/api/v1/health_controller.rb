# frozen_string_literal: true

module Api
  module V1
    # Controller for healthcheck endpoint to monitor application and database status
    class HealthController < ApplicationController
      skip_before_action :authenticate_user!

      # GET /api/v1/health
      # Healthcheck endpoint to verify application and database status
      # Returns 200 OK if healthy, 503 Service Unavailable if database is unreachable
      def index
        database_status = check_database_connectivity

        if database_status[:connected]
          render json: {
            status: 'healthy',
            timestamp: Time.current.utc.iso8601,
            database: 'connected'
          }, status: :ok
        else
          render json: {
            status: 'unhealthy',
            timestamp: Time.current.utc.iso8601,
            database: 'disconnected',
            error: database_status[:error]
          }, status: :service_unavailable
        end
      end

      private

      # Check database connectivity by executing a simple query
      # @return [Hash] connection status and error message if any
      def check_database_connectivity
        # Execute a simple query to ensure database is responsive
        # This is more reliable than checking active? status
        ActiveRecord::Base.connection.execute('SELECT 1')
        { connected: true }
      rescue StandardError => e
        { connected: false, error: e.message }
      end
    end
  end
end
