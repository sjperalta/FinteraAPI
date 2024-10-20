# app/services/contracts/reject_contract_service.rb

module Contracts
  class RejectContractService
    def initialize(contract:)
      @contract = contract
    end

    def call
      if @contract.update(status: 'rejected')
        { success: true, message: 'Solicitud rechazada' }
      else
        { success: false, errors: @contract.errors.full_messages }
      end
    end
  end
end
