# app/jobs/check_payments_overdue_job.rb

class CheckPaymentsOverdueJob < ApplicationJob
  queue_as :default

  def perform
    # Buscar todos los pagos pendientes cuya fecha de vencimiento haya pasado
    overdue_payments = Payment.where("due_date < ? AND status = ?", Date.today, 'pending')

    # Agrupar los pagos por usuario
    overdue_payments.group_by(&:user).each do |user, payments|
      # Enviar un email al usuario con los detalles de sus pagos vencidos
      Notifications::OverduePaymentEmailService.new(user, payments).call
    end
  end
end
