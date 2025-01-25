module Statistics
  class RevenueService
    # Generate and store revenue data for the given year and month
    def self.generate_and_store_revenue(year, month)
      ["reservation", "down_payment", "installment"].each do |payment_type|
        amount = calculate_monthly_revenue(year, month, payment_type)

        # Store the calculated revenue in the database
        Revenue.find_or_initialize_by(payment_type: payment_type, year: year, month: month).tap do |revenue|
          revenue.amount = amount
          revenue.save!
        end

        notify_admin
      end
    end

    # Generate revenue data for the current month and store it
    def self.generate_for_current_month
      today = Date.today
      generate_and_store_revenue(today.year, today.month)
    end

    private

    # Helper method to calculate monthly revenue for a specific payment type
    def self.calculate_monthly_revenue(year, month, payment_type)
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_monthds

      # Query the Payment table for the given type and date range
      Payment.where(payment_type: payment_type, due_date: start_date..end_date).sum(:amount)
    end

    def notify_admin
      users = User.where(role: 'admin')
      users.each do |user|
        Notification.create(
          user: user,
          title: "Estadisticas de Flujo de Efectivo",
          message: "Se ha ejecutado el servicio de actualizacion de Flujo de Efectivo.",
          notification_type: "generate_revenue_statistics"
        )
      end
    end
  end
end
