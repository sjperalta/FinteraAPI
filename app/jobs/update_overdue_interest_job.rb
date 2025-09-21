class UpdateOverdueInterestJob < ApplicationJob
  queue_as :default

  # This method calculates the daily interest rate assuming
  # an annual rate is divided by 365 days, then multiplies
  # by the number of overdue days.
  def calculate_overdue_interest(payment, project_interest_rate)
    daily_interest_rate = project_interest_rate / 100.0 / 365
    overdue_days = (Date.current - payment.due_date).to_i

    # we start to count as overdue at the next day
      return 0 if overdue_days <= 1

      project_interest_rate = project_interest_rate.to_f
      daily_interest_rate = project_interest_rate / 100.0 / 365.0
      (payment.amount.to_f * daily_interest_rate * overdue_days).round(2)
  end

  def send_notification(payment, overdue_interest)
    Notification.create(
      user: payment.contract.applicant_user,
      title: "Pago Atrasado: #{payment.description}",
      message: "Se ha generado un cargo por mora de #{overdue_interest}.",
      notification_type: "payment_overdue"
    )
  end

  def notify_admin(admin, count)
    Notification.create(
      user: admin,
      title: "Se Ejecuto Servicio de Actualización Saldos en Mora.",
      message: "Se ha generado un cargo por mora a #{count} usuarios.",
      notification_type: "payment_overdue_admin"
    )
  end

  def perform
    overdue_payments = Payment.joins(contract: { lot: :project })
                                .where("payments.due_date < ? AND payments.status = ?", Date.current, 'pending')

      processed_count = 0

      overdue_payments.each do |payment|
        begin
          project_interest_rate = payment.contract.lot.project.interest_rate
          overdue_interest = calculate_overdue_interest(payment, project_interest_rate)

          # Optional: skip updating if there's no new interest accrued
          next if overdue_interest == payment.interest_amount

          payment.update!(interest_amount: overdue_interest)
          send_notification(payment, overdue_interest)
          Rails.logger.info "[UpdateOverdueInterestJob] Payment ID #{payment.id} updated with overdue interest: #{overdue_interest}"
          processed_count += 1
        rescue StandardError => e
          Rails.logger.error "[UpdateOverdueInterestJob] Error processing payment_id=#{payment&.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n") if e.backtrace
          Sentry.capture_exception(e) if defined?(Sentry)
          next
        end
      end

      begin
        user_admin = User.find_by(role: 'admin')
        notify_admin(user_admin, processed_count)
        Rails.logger.info "[UpdateOverdueInterestJob] Admin notified about #{processed_count} updated payments"
      rescue StandardError => e
        Rails.logger.error "[UpdateOverdueInterestJob] Error notifying admin: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        Sentry.capture_exception(e) if defined?(Sentry)
      end
  end
end
