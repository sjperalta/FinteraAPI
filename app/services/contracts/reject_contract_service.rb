# app/services/contracts/reject_contract_service.rb

module Contracts
  class RejectContractService
    def initialize(contract:)
      @contract = contract
    end

    def call
      send_reject_notification
      @contract.lot.update(status: 'available')

      if @contract.update(status: 'rejected', active: false)
        { success: true, message: 'Solicitud rechazada' }
      else
        { success: false, errors: @contract.errors.full_messages }
      end
    end

    def send_reject_notification
      Notification.create(
        user: @contract.applicant_user,
        title: "Contrato Rechazado",
        message: "Tu contrato fue rechado #{@contract.lot.name}",
        notification_type: "contract_rejected"
      )
    end
  end
end
