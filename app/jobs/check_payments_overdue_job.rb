# app/jobs/check_payments_overdue_job.rb
class CheckPaymentsOverdueJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckPaymentsOverdueJob] Fetching overdue payments"
    overdue_payments = Payment.joins(:contract)
                              .where("payments.due_date < ? AND payments.status = ?", Date.today, "pending")

    overdue_payments.group_by { |payment| payment.contract.applicant_user }.each do |user, payments|
      next unless valid_user?(user)

      Notifications::OverduePaymentEmailService.new(user, payments).call
      Rails.logger.info "[CheckPaymentsOverdueJob] Notified user_id=#{safe_user_id(user)} for #{payments.size} overdue payments"
    end
  end

  private

  def valid_user?(user)
    return false if user.nil?
    return user.present? if user.respond_to?(:present?)

    true
  end

  def safe_user_id(user)
    user.respond_to?(:id) ? user.id : "unknown"
  end
end
