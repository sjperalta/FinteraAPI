class Api::V1::ReportsController < ActionController::Base
  def commissions_csv
    generate_csv(Reports::CommissionsReportService, "commissions_report.csv")
  end

  def total_revenue_csv
    generate_csv(Reports::TotalRevenueReportService, "total_revenue_report.csv")
  end

  def overdue_payments_csv
    generate_csv(Reports::OverduePaymentsReportService, "overdue_payments_report.csv")
  end

  def user_balance_pdf
    service = Reports::UserBalanceService.new(params[:user_id])
    result = service.call

    return render json: { error: result[:error] }, status: :not_found unless result[:success]

    # required parameters in the pdf html code
    @user = result[:user]
    @balance = result[:balance]
    @pending_payments = result[:pending_payments]

    respond_to do |format|
      format.pdf do
        render pdf: "user_balance_#{params[:user_id]}",
               template: "reports/user_balance",
               formats: [:html],
               layout: "pdf",
               disposition: "attachment"
      end
    end
  rescue => e
    Rails.logger.error "Error generating User Balance PDF: #{e.message}"
    render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
  end

  private

  def parse_date_range
    [
      params[:start_date].presence || Date.current.beginning_of_month.to_s,
      params[:end_date].presence || Date.current.end_of_month.to_s
    ]
  end

  def generate_csv(service_class, filename)
    start_date, end_date = parse_date_range
    csv_data = service_class.new(start_date, end_date).call

    send_data csv_data,
              filename: filename,
              type: "text/csv; charset=UTF-8; header=present",
              disposition: "attachment"
  end
end
