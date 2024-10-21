module Contracts
  class CreateContractService
    def initialize(lot:, contract_params:, documents:, current_user:)
      @lot = lot
      @contract_params = contract_params
      @documents = documents
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        contract = create_contract
        attach_documents(contract) if @documents.present?
        update_lot_status

        { success: true, contract: contract }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, errors: e.record.errors.full_messages }
      end
    end

    private

    def create_contract
      contract = @lot.contracts.build(@contract_params)
      contract.creator = @current_user
      contract.save! # Usamos bang para lanzar una excepción si falla
      contract
    end

    def attach_documents(contract)
      contract.documents.attach(@documents)
    end

    def update_lot_status
      @lot.update!(status: 'reserved')
    end
  end
end
