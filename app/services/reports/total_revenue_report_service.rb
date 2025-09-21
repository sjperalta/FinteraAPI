require 'csv'

module Reports
  class TotalRevenueReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
      @locale = I18n.default_locale
    end

    def call(locale: nil)
      @locale = locale || I18n.default_locale
      payments = fetch_payments

      total_paid = payments.sum(:paid_amount).to_f
      total_interest = payments.sum(:interest_amount).to_f
      grand_total = total_paid + total_interest

      CSV.generate(headers: true) do |csv|
        csv << csv_headers

        payments.each { |p| csv << generate_csv_row(p) }

        csv << []
        csv << [I18n.t("reports.total_revenue.summary", locale: @locale)]
        csv << [I18n.t("reports.total_revenue.total_paid", locale: @locale), total_paid]
        csv << [I18n.t("reports.total_revenue.total_interest", locale: @locale), total_interest]
        csv << [I18n.t("reports.total_revenue.grand_total", locale: @locale), grand_total]
      end
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.total_revenue.errors.generate_csv", message: e.message, locale: @locale)
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

    def csv_headers
      t = ->(key) { I18n.t("reports.total_revenue.csv.headers.#{key}", locale: @locale) }
      [
        t.call(:id_payment),
        t.call(:description),
        t.call(:paid_amount),
        t.call(:interest_amount),
        t.call(:due_date),
        t.call(:payment_date)
      ]
    end
  end
end
