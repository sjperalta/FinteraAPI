require 'csv'

module Reports
  class OverduePaymentsReportService
    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
      @locale = I18n.default_locale
    end

    def call(locale: nil)
      @locale = locale || I18n.default_locale
      overdue_payments = fetch_overdue_payments

      total_amount = overdue_payments.sum(:amount).to_f
      total_interest = overdue_payments.sum(:interest_amount).to_f

      CSV.generate(headers: true) do |csv|
        csv << csv_headers

        overdue_payments.each { |p| csv << generate_csv_row(p) }

        csv << []
        csv << [I18n.t("reports.overdue_payments.summary", locale: @locale)]
        csv << [I18n.t("reports.overdue_payments.total_amount", locale: @locale), total_amount]
        csv << [I18n.t("reports.overdue_payments.total_interest", locale: @locale), total_interest]
      end
    rescue StandardError => e
      Rails.logger.error I18n.t("reports.overdue_payments.errors.generate_csv", message: e.message, locale: @locale)
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

    def csv_headers
      t = ->(key) { I18n.t("reports.overdue_payments.csv.headers.#{key}", locale: @locale) }
      [
        t.call(:id_payment),
        t.call(:full_name),
        t.call(:email),
        t.call(:phone),
        t.call(:description),
        t.call(:amount),
        t.call(:interest),
        t.call(:due_date),
        t.call(:overdue_days)
      ]
    end
  end
end
