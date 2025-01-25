# app/services/contracts/approve_contract_service.rb

module Contracts
  class ApproveContractService
    def initialize(contract:, current_user:)
      @contract = contract
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        approve_contract
        generate_payments
        save_notification
      end

      send_approval_notification

      { success: true, message: 'Contrato aprobado exitosamente.' }
    rescue => e
      error_message = "Error aprobando la reserva: #{e.message}"
      Rails.logger.error(error_message)
      { success: false, errors: [error_message] }
    end

    private

    def approve_contract
      @contract.update!(status: 'approved', approved_at: Time.current)
    end

    # Método para generar los pagos dependiendo del tipo de financiamiento
    def generate_payments
      @contract.create_payments
    end

    def save_notification
      Notification.create(
        user: @contract.applicant_user,
        title: "Contrato Aprobado",
        message: "Tu contrato fue aprobado #{@contract.lot.name}",
        notification_type: "contract_approved"
      )
    end

    def send_approval_notification
      # Ejecutar el Job en segundo plano
      SendContractApprovalNotificationJob.perform_now(@contract)
    end
  end
end
