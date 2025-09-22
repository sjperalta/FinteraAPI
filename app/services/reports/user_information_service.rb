# frozen_string_literal: true

module Reports
  class UserInformationService
    def initialize(contract_id)
      @contract_id = contract_id
      @locale = I18n.default_locale
    end

    def call
      contract = Contract.includes(:applicant_user, :lot).find_by(id: @contract_id)
      unless contract
        return { success: false,
                 error: I18n.t('reports.user_information.errors.not_found', locale: @locale) }
      end

      applicant = contract.applicant_user
      unless applicant
        return { success: false,
                 error: I18n.t('reports.user_information.errors.user_not_found', locale: @locale) }
      end

      {
        success: true,
        applicant:,
        contract:,
        lot: contract.lot,
        project: contract.lot.project,
        payment: contract.payments&.last
      }
    rescue StandardError => e
      Rails.logger.error I18n.t('reports.user_information.errors.not_found', message: e.message, locale: @locale)
      { success: false, error: e.message }
    end
  end
end
