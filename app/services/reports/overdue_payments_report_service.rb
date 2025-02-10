require 'csv'

module Reports
  class OverduePaymentsReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
    end

    def call
      overdue_payments = fetch_overdue_payments

      total_amount = overdue_payments.sum(:amount).to_f
      total_interest = overdue_payments.sum(:interest_amount).to_f

      CSV.generate(headers: true) do |csv|
        csv << ["Id Pago", "Nombre Completo", "Email", "Telefono", "Descripcion", "Cantidad", "Intereses", "Fecha de Pago", "Dias de Mora"]

        overdue_payments.each { |p| csv << generate_csv_row(p) }

        csv << []
        csv << ["Summary"]
        csv << ["Total Cantidad", total_amount]
        csv << ["Total Intereses", total_interest]
      end
    rescue StandardError => e
      Rails.logger.error "Error generating overdue payments CSV: #{e.message}"
      raise e
    end

    private

    def fetch_overdue_payments
      Payment.joins(contract: :applicant_user)
             .where(status: 'pending', due_date: @start_date..@end_date)
             .where("payments.due_date < ?", Date.current)
    end

    def generate_csv_row(payment)
      user = payment.contract.applicant_user
      overdue_days = (Date.current - payment.due_date).to_i

      [
        payment.id,
        user&.full_name,
        user&.email,
        user&.phone,
        payment.description,
        payment.amount.to_f,
        payment.interest_amount.to_f,
        payment.due_date,
        overdue_days - 1
      ]
    end
  end
end
