require 'csv'

module Reports
  class CommissionsReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
      @locale = I18n.default_locale
    end


    def call(locale: nil)
      @locale = locale || I18n.default_locale
      contracts = fetch_contracts

      CSV.generate(headers: true) do |csv|
        csv << csv_headers

        contracts.each do |contract|
          csv << generate_csv_row(contract)
        end
      end
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.commissions.errors.generate_csv", message: e.message, locale: @locale)
      raise e
    end

    private

    def fetch_contracts
      Contract.approved_between(@start_date, @end_date).with_creator_and_lot
    end

    def generate_csv_row(contract)
      full_name = contract.creator&.full_name || "N/A"
      commission_rate = contract.lot.project.commission_rate || 0
      total_commission = (contract.amount * (commission_rate / 100)).round(2)

      [
        contract.creator_id,
        full_name,
        contract.approved_at,
        "#{contract.lot.project.name} - #{contract.lot.name}",
        contract.amount,
        "#{commission_rate} %",
        total_commission
      ]
    end

    def csv_headers
      t = ->(key) { I18n.t("reports.commissions.csv.headers.#{key}", locale: @locale) }
      [
        t.call(:user_id),
        t.call(:full_name),
        t.call(:date),
        t.call(:description),
        t.call(:amount),
        t.call(:commission_percent),
        t.call(:commission_total)
      ]
    end
  end
end
