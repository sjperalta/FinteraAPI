# frozen_string_literal: true

# app/services/users/user_summary_service.rb
module Users
  # Service to compile a summary of a user's financial and contract information.
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

    # sum of the contract has a field balance, make sure to sum only approved contracts
    def balance
      @user.contracts.where(status: Contract::STATUS_APPROVED).sum(:balance)
    end

    # count pending payments that are overdue, sum their amounts and fees, and count them
    def overdue_aggregate
      @overdue_aggregate ||= begin
        scope = @user.payments
                     .where(status: %w[pending])
                     .where('payments.due_date < ?', Date.today)

        # Use pluck to get the three aggregates in a single DB roundtrip: total_due, total_fees, overdue_count
        result = scope.joins(:contract)
                      .pluck(Arel.sql('COALESCE(SUM(payments.amount),0)'),
                             Arel.sql('COALESCE(SUM(payments.interest_amount),0)'),
                             Arel.sql('COUNT(payments.id)'))

        result.first || [0, 0, 0]
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
      Contract.joins(lot: :project).where(applicant_user_id: @user.id,
                                          status: 'approved').distinct.pluck('projects.name')
    end
  end
end
