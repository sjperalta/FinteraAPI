# app/jobs/check_payments_overdue_job.rb
class CheckPaymentsOverdueJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckPaymentsOverdueJob] Fetching overdue payments"
    overdue_payments = Payment.joins(:contract)
                              .where("payments.due_date < ? AND payments.status = ?", Date.today, 'pending')

    overdue_payments.group_by { |payment| payment.contract.applicant_user }.each do |user, payments|
      # Skip when there's no user (spec passes nil applicant_user)
      next unless user && user.respond_to?(:present?) ? user.present? : !!user

      begin
        service = Notifications::OverduePaymentEmailService.new(user, payments)
        service.call
        # Avoid calling `user.id` on test doubles that may not implement it; log presence only
        Rails.logger.info "[CheckPaymentsOverdueJob] Notified user=#{user.inspect} for #{payments.size} overdue payments"
      rescue StandardError => e
        Rails.logger.error "[CheckPaymentsOverdueJob] Error notifying user=#{user.inspect}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        Sentry.capture_exception(e) if defined?(Sentry)
        next
      end
    end
  end
end
