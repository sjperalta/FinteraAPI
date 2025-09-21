module Reports
  class UserRescissionContractService
    PENALTY_PERCENTAGE = 0.10

    def initialize(contract_id)
      @contract_id = contract_id
      @locale = I18n.default_locale
    end

    def call
      contract = Contract.includes(:lot, lot: :project).find_by(id: @contract_id, status: 'rejected')
      return { success: false, error: I18n.t("reports.user_rescission.errors.not_found", locale: @locale) } unless contract

      applicant = contract.applicant_user
      creator = contract.creator
      lot = contract.lot
      project = lot.project

      {
        success: true,
        applicant: applicant,
        creator: creator,
        contract: contract,
        lot: lot,
        project: project,
        refund_amount: contract.reserve_amount - (contract.reserve_amount * PENALTY_PERCENTAGE),
        penalty_amount: contract.reserve_amount * PENALTY_PERCENTAGE,
        reservation_amount: contract.reserve_amount
      }
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.user_rescission.errors.not_found", message: e.message, locale: @locale)
      { success: false, error: e.message }
    end
  end
end
