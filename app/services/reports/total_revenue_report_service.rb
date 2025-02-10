require 'csv'

module Reports
  class TotalRevenueReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
    end

    def call
      payments = fetch_payments

      total_paid = payments.sum(:paid_amount).to_f
      total_interest = payments.sum(:interest_amount).to_f
      grand_total = total_paid + total_interest

      CSV.generate(headers: true) do |csv|
        csv << ["ID Pago", "Description", "Paid Amount", "Interest Amount", "Due Date", "Payment Date"]

        payments.each { |p| csv << generate_csv_row(p) }

        csv << []
        csv << ["Summary"]
        csv << ["Total Paid", total_paid]
        csv << ["Total Interest", total_interest]
        csv << ["Grand Total", grand_total]
      end
    rescue StandardError => e
      Rails.logger.error "Error generating total revenue CSV: #{e.message}"
      raise e
    end

    private

    def fetch_payments
      Payment.where(status: 'paid', payment_date: @start_date..@end_date)
    end

    def generate_csv_row(payment)
      [
        payment.id,
        payment.description,
        payment.paid_amount.to_f,
        payment.interest_amount.to_f,
        payment.due_date,
        payment.payment_date
      ]
    end
  end
end
