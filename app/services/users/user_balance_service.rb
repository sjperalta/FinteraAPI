module Users
  class UserBalanceService
    def initialize(user_id, current_user = nil)
      @user_id = user_id
      @current_user = current_user
    end

    def call
      user = User.find_by(id: @user_id)
      return { success: false, error: "User not found" } unless user
      notify_user(user)

      {
        success: true,
        user: user,
        balance: user_balance(user),
        pending_payments: overdue_payments(user)
      }
    end

    private

    def user_balance(user)
      user.payments.sum(:amount) - user.payments.sum(:paid_amount)
    end

    def overdue_payments(user)
      user.payments.overdue
    end

    def notify_user(user)
      unless @current_user.nil?
        Notification.create(
          user: @current_user,
          title: "Se ha generado reporte de balance",
          message: "Se ha generado reporte de balance para #{user.full_name}",
          notification_type: "create_user_balance"
        )
      end
    end
  end
end
