# frozen_string_literal: true

# app/services/reports/user_promise_contract_service.rb
module Reports
  # Service to gather comprehensive data about a user's promise contract
  class UserPromiseContractService
    ALLOWED_FINANCING = %w[direct bank cash].freeze

    def initialize(contract_id, financing_type = 'direct')
      @contract_id = contract_id
      @financing_type = financing_type.to_s
      @locale = I18n.default_locale
    end

    def call
      # 1. Busca el contrato y sus relaciones
      contract = Contract.includes(:lot, lot: :project)
                         .find_by(id: @contract_id)
      return { success: false, error: I18n.t('reports.user_promise.errors.not_found', locale: @locale) } unless contract

      # 2. Identifica al cliente (applicant), el proyecto y el lote
      applicant = contract.applicant_user
      project   = contract.lot.project
      lot       = contract.lot

      unless applicant && project && lot
        return { success: false,
                 error: I18n.t('reports.user_promise.errors.missing_data',
                               locale: @locale) }
      end

      # 3. Obtiene la primera y última cuota (si existen)
      payments = contract.payments.order(:due_date)

      first_payment = payments.first
      last_payment  = payments.last

      # Validate financing type
      unless ALLOWED_FINANCING.include?(@financing_type)
        return { success: false,
                 error: I18n.t('reports.user_promise.errors.invalid_financing', financing: @financing_type,
                                                                                locale: @locale) }
      end

      # Ensure template exists for the financing type
      template_name = "reports/user_promise_contract_#{@financing_type}"

      # Robust template existence check: search Rails view paths for common template extensions
      view_paths = ActionController::Base.view_paths.map { |p| p.to_path }
      basename = "user_promise_contract_#{@financing_type}"
      exts = %w[.html.erb .erb .html.haml .html.slim]
      found = view_paths.any? do |vp|
        exts.any? { |ext| File.exist?(File.join(vp, 'reports', "#{basename}#{ext}")) }
      end

      unless found
        Rails.logger.error "Missing Promesa template (searched paths): #{template_name}"
        return { success: false,
                 error: I18n.t('reports.user_promise.errors.template_missing', template: template_name,
                                                                               locale: @locale) }
      end

      # 5. Retorna todos los datos que la plantilla podría necesitar
      {
        success: true,
        contract:,
        applicant:,
        project:,
        lot:,
        financing_amount: contract.calculate_financing_amount,
        first_payment:,
        last_payment:,
        template_name:
      }
    rescue StandardError => e
      Rails.logger.error I18n.t('reports.user_promise.errors.not_found', message: e.message, locale: @locale)
      { success: false, error: e.message }
    end
  end
end
