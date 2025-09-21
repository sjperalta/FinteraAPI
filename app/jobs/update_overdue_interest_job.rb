class UpdateOverdueInterestJob < ApplicationJob
  queue_as :default

  DAYS_PER_YEAR = 365.0

  # Keep per-payment error handling to continue processing remaining payments.
  def calculate_overdue_interest(payment, project_interest_rate)
    daily_interest_rate = project_interest_rate.to_f / 100.0 / DAYS_PER_YEAR
    overdue_days = (Date.current - payment.due_date).to_i
    return 0 if overdue_days <= 1
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
    return unless admin
    Notification.create(
      user: admin,
      title: "Se Ejecuto Servicio de Actualización Saldos en Mora.",
      message: "Se ha generado un cargo por mora a #{count} usuarios.",
      notification_type: "payment_overdue_admin"
    )
  end

  # Allow admin notification errors to be swallowed so the job does not fail if notifications fail.
  self.swallow_exceptions = true

  def perform
    Rails.logger.info "[UpdateOverdueInterestJob] starting overdue interest update"
    overdue_payments = Payment.joins(contract: { lot: :project })
                              .where("payments.due_date < ? AND payments.status = ?", Date.current, "pending")

    processed_count = 0
    overdue_payments.each do |payment|
      begin
        project_interest_rate = payment.contract.lot.project.interest_rate
        overdue_interest = calculate_overdue_interest(payment, project_interest_rate)
        next if overdue_interest == payment.interest_amount
        payment.update!(interest_amount: overdue_interest)
        send_notification(payment, overdue_interest)
        Rails.logger.info "[UpdateOverdueInterestJob] updated payment_id=#{payment.id} interest=#{overdue_interest}"
        processed_count += 1
      rescue StandardError => e
        # per-payment error handling — keep processing others
        Rails.logger.error "[UpdateOverdueInterestJob] error processing payment_id=#{payment&.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        Sentry.capture_exception(e) if defined?(Sentry)
        next
      end
    end

    admin = User.find_by(role: "admin")
    notify_admin(admin, processed_count)
    Rails.logger.info "[UpdateOverdueInterestJob] admin notified about #{processed_count} updates"
  end
end
