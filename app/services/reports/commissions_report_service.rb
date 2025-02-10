require 'csv'

module Reports
  class CommissionsReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
    end

    def call
      contracts = fetch_contracts

      CSV.generate(headers: true) do |csv|
        csv << ["Id Usuario", "Nombre Completo", "Fecha", "Descripción", "Cantidad", "% Comisión", "Comisión Total"]

        contracts.each do |contract|
          csv << generate_csv_row(contract)
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error generating commissions CSV: #{e.message}"
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
  end
end
