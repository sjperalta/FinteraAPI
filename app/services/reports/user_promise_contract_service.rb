# app/services/reports/user_promise_contract_service.rb
module Reports
  class UserPromiseContractService
    def initialize(contract_id)
      @contract_id = contract_id
      @locale = I18n.default_locale
    end

    def call
      # 1. Busca el contrato y sus relaciones
  contract = Contract.includes(:lot, lot: :project)
         .find_by(id: @contract_id)
  return { success: false, error: I18n.t("reports.user_promise.errors.not_found", locale: @locale) } unless contract

      # 2. Identifica al cliente (applicant), el proyecto y el lote
      applicant = contract.applicant_user
      project   = contract.lot.project
      lot       = contract.lot

  return { success: false, error: I18n.t("reports.user_promise.errors.missing_data", locale: @locale) } unless applicant && project && lot

      # 3. Obtiene la primera y última cuota (si existen)
      payments = contract.payments.order(:due_date)

      first_payment = payments.first
      last_payment  = payments.last

      # 5. Retorna todos los datos que la plantilla podría necesitar
      {
        success:         true,
        contract:        contract,
        applicant:       applicant,
        project:         project,
        lot:             lot,
        financing_amount: contract.calculate_financing_amount,
        first_payment:   first_payment,
        last_payment:    last_payment
      }
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.user_promise.errors.not_found", message: e.message, locale: @locale)
      { success: false, error: e.message }
    end
  end
end
