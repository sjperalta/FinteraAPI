# app/jobs/check_payments_overdue_job.rb
class CheckPaymentsOverdueJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckPaymentsOverdueJob] Fetching overdue payments"
    overdue_payments = Payment.joins(:contract)
                              .where("payments.due_date < ? AND payments.status = ?", Date.today, 'pending')

    overdue_payments.group_by { |payment| payment.contract.applicant_user }.each do |user, payments|
      next unless valid_user?(user)

      begin
        service = Notifications::OverduePaymentEmailService.new(user, payments)
        service.call
        Rails.logger.info "[CheckPaymentsOverdueJob] Notified user_id=#{safe_user_id(user)} for #{payments.size} overdue payments"
      rescue StandardError => e
        Rails.logger.error "[CheckPaymentsOverdueJob] Error notifying user_id=#{safe_user_id(user)}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        Sentry.capture_exception(e) if defined?(Sentry)
        next
      end
    end
  end

  private

  def valid_user?(user)
    return false if user.nil?
    return user.present? if user.respond_to?(:present?)

    true
  end

  def safe_user_id(user)
    user.respond_to?(:id) ? user.id : 'unknown'
  end
end
