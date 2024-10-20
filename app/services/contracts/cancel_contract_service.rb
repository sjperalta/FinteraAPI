# app/services/contracts/cancel_contract_service.rb

module Contracts
  class CancelContractService
    def initialize(contract:)
      @contract = contract
    end

    def call
      if @contract.update(status: 'cancelled')
        { success: true, message: 'Solicitud cancelada' }
      else
        { success: false, errors: @contract.errors.full_messages }
      end
    end
  end
end
