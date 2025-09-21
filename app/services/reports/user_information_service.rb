module Reports
  class UserInformationService
    def initialize(contract_id)
      @contract_id = contract_id
      @locale = I18n.default_locale
    end

    def call
      contract = Contract.includes(:applicant_user, :lot).find_by(id: @contract_id)
      return { success: false, error: I18n.t("reports.user_information.errors.not_found", locale: @locale) } unless contract

      applicant = contract.applicant_user
      return { success: false, error: I18n.t("reports.user_information.errors.user_not_found", locale: @locale) } unless applicant

      {
        success: true,
        applicant: applicant,
        contract: contract,
        lot: contract.lot,
        project: contract.lot.project,
        payment: contract.payments&.last
      }
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.user_information.errors.not_found", message: e.message, locale: @locale)
      { success: false, error: e.message }
    end
  end
end
