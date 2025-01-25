# app/jobs/check_payments_overdue_job.rb
class CheckPaymentsOverdueJob < ApplicationJob
  queue_as :default

  def perform
    # Fetch overdue payments that are still pending
    overdue_payments = Payment.joins(:contract)
                              .where("payments.due_date < ? AND payments.status = ?", Date.today, 'pending')

    # Group overdue payments by applicant_user
    overdue_payments.group_by { |payment| payment.contract.applicant_user }.each do |user, payments|
      next unless user.present? # Skip if the user doesn't exist (just in case)

      # Send email notification to the user about overdue payments
      Notifications::OverduePaymentEmailService.new(user, payments).call
    end
  end
end
