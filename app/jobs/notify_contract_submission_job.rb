# app/jobs/notify_admin_payment_receipt_job.rb

class NotifyContractSubmissionJob < ApplicationJob
  queue_as :default

  def perform(payment)
    @payment = payment
    # Llamamos al servicio que notifica al administrador
    send_contract_notification_email
  end

  private

  def send_contract_notification_email
    Notifications::ContractSubmissionEmailService.new(@payment).call
  end
end
