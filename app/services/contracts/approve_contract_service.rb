# app/services/contracts/approve_contract_service.rb

module Contracts
  class ApproveContractService
    def initialize(contract:, current_user:)
      @contract = contract
      @financing_type = @contract.financing_type
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        approve_contract
        generate_payments
        send_approval_notification
      end
      { success: true, message: 'Approbado' }
    rescue => e
      error_message = "Error aprobando la reserva: #{e.message}"
      Rails.logger.error(error_message)
      { success: true, errors: [error_message] }
    end

    private

    def approve_contract
      @contract.update!(status: 'approved', approved_at: Time.current)
    end

    # Método para generar los pagos dependiendo del tipo de financiamiento
    def generate_payments
      @contract.create_payments
    end

    def send_approval_notification
      # Ejecutar el Job en segundo plano
      SendContractApprovalNotificationJob.perform_later(@contract)
    end
  end
end
