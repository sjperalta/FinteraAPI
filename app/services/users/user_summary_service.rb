# app/services/users/user_summary_service.rb
module Users
  class UserSummaryService
    def initialize(user)
      @user = user
    end

    def call
      {
        currency: currency,
        balance: balance.to_f,
        totalDue: total_due.to_f,
        totalFees: total_fees.to_f,
        overdueCount: overdue_count
      }
    end

    private

    def currency
      payment = @user.payments.first
      currency = payment.blank? ? "HNL" : payment.contract.currency
      currency
    end

    def balance
      @user.payments.sum(:amount) - @user.payments.sum(:paid_amount)
    end

    def overdue_payments
      @overdue_payments ||= @user.payments
                                  .where(status: ['pending', 'submitted', 'correction_required'])
                                  .where('due_date < ?', Date.today)
    end

    def total_due
      overdue_payments.sum(:amount)
    end

    def total_fees
      overdue_payments.sum(:interest_amount)
    end

    def overdue_count
      overdue_payments.count
    end
  end
end
