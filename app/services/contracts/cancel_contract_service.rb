# app/services/contracts/cancel_contract_service.rb

module Contracts
  class CancelContractService
    def initialize(contract:)
      @contract = contract
    end

    def call
      @contract.lot.update(status: 'available')
      if @contract.update(status: 'cancelled', active: false)
        { success: true, message: 'Solicitud cancelada' }
      else
        { success: false, errors: @contract.errors.full_messages }
      end
    end
  end
end
