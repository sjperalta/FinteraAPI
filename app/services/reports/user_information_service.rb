module Reports
  class UserInformationService
    def initialize(contract_id)
      @contract_id = contract_id
    end

    def call
      contract = Contract.includes(:applicant_user, :lot).find_by(id: @contract_id)
      return { success: false, error: "Contract not found" } unless contract

      applicant = contract.applicant_user
      return { success: false, error: "User not found for contract" } unless applicant

      {
        success: true,
        applicant: applicant,
        contract: contract,
        lot: contract.lot,
        project: contract.lot.project,
        payment: contract.payments&.last
      }
    rescue StandardError => e
      Rails.logger.error "UserInformationService Error: #{e.message}"
      { success: false, error: e.message }
    end
  end
end
