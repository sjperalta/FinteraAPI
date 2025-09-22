# frozen_string_literal: true

module Statistics
  class RevenueService
    # Generate and store revenue data for the given year and month
    def self.generate_and_store_revenue(year, month)
      # Process each payment type and store revenue data
      %w[reservation down_payment installment].each do |payment_type|
        amount = calculate_monthly_revenue(year, month, payment_type)

        # Store the calculated revenue in the database
        Revenue.find_or_initialize_by(payment_type:, year:, month:).tap do |revenue|
          revenue.amount = amount
          revenue.save!
        end
      end

      # Notify admin once after processing all payment types.
      notify_admin
    end

    # Generate revenue data for the current month and store it
    def self.generate_for_current_month
      today = Date.today
      generate_and_store_revenue(today.year, today.month)
    end

    # Helper method to calculate monthly revenue for a specific payment type
    def self.calculate_monthly_revenue(year, month, payment_type)
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month # Fixed typo: end_of_monthds -> end_of_month

      # Query the Payment table for the given type and date range
      Payment.where(payment_type:, due_date: start_date..end_date).sum(:amount)
    end

    # Define notify_admin as a class method so it can be called from within a class method
    def self.notify_admin
      admins = User.where(role: 'admin')
      admins.each do |admin|
        Notification.create(
          user: admin,
          title: 'Estadisticas de Flujo de Efectivo',
          message: 'Se ha ejecutado el servicio de actualizacion de Flujo de Efectivo.',
          notification_type: 'generate_revenue_statistics'
        )
      end
    end
  end
end
