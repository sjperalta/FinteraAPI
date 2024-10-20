# app/services/contracts/create_contract_service.rb

module Contracts
  class CreateContractService
    def initialize(lot:, contract_params:, documents:, current_user:)
      @lot = lot
      @contract_params = contract_params
      @documents = documents
      @current_user = current_user
    end

    def call
      contract = @lot.contracts.build(@contract_params)
      contract.creator = @current_user

      if contract.save
        contract.documents.attach(@documents) if @documents.present?
        { success: true, contract: contract }
      else
        { success: false, errors: contract.errors.full_messages }
      end
    end
  end
end
