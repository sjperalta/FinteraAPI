# frozen_string_literal: true

# app/services/users/user_summary_service.rb
module Users
  class UserSummaryService
    def initialize(user)
      @user = user
    end

    def call
      {
        currency:,
        balance: balance.to_f,
        totalDue: total_due.to_f,
        totalFees: total_fees.to_f,
        overdueCount: overdue_count,
        contractList: contract_list
      }
    end

    private

    def currency
      # fetch currency from the first payment's contract in one query
      currency = @user.payments.joins(:contract).limit(1).pluck('contracts.currency').first
      currency || 'HNL'
    end

    def balance
      # aggregate amount and paid_amount in one query to avoid two SUM queries
      totals = @user.payments.pluck(Arel.sql('COALESCE(SUM(payments.amount),0), COALESCE(SUM(payments.paid_amount),0)')).first
      total_amount = totals&.first.to_d || 0
      total_paid = totals&.last.to_d || 0
      (total_amount - total_paid)
    end

    def overdue_aggregate
      @overdue_aggregate ||= begin
        scope = @user.payments
                     .where(status: %w[pending submitted correction_required])
                     .where('payments.due_date < ?', Date.today)

        scope.pluck(Arel.sql('COALESCE(SUM(payments.amount),0), COALESCE(SUM(payments.interest_amount),0), COUNT(*)')).first || [
          0, 0, 0
        ]
      end
    end

    def total_due
      overdue_aggregate[0].to_d
    end

    def total_fees
      overdue_aggregate[1].to_d
    end

    def overdue_count
      overdue_aggregate[2].to_i
    end

    def contract_list
      # Fetch distinct project names in a single query to avoid N+1
      Contract.joins(lot: :project).where(applicant_user_id: @user.id).distinct.pluck('projects.name')
    end
  end
end
