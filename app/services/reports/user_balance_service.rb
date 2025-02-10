module Reports
  class UserBalanceService
    def initialize(user_id)
      @user = User.find_by(id: user_id)
      @admin_user = User.find_by(role: "admin")
    end

    def call
      return { success: false, error: "User not found" } unless @user
      notify_user

      {
        success: true,
        user: @user,
        balance: calculate_balance,
        pending_payments: fetch_pending_payments
      }
    rescue StandardError => e
      Rails.logger.error "Error fetching user balance: #{e.message}"
      { success: false, error: e.message }
    end


    private

    def calculate_balance
      @user.payments.sum(:amount) - @user.payments.sum(:paid_amount)
    end

    def fetch_pending_payments
      @user.payments.pending.overdue
    end

    def notify_user
      return nil if @admin_user.blank?

      Notification.create(
        user: @admin_user,
        title: "Se ha generado reporte de balance",
        message: "Se ha generado reporte de balance para #{@user.full_name}",
        notification_type: "create_user_balance"
      )
    end
  end
end
