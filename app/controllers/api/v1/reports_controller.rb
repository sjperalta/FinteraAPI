# frozen_string_literal: true

module Api
  module V1
    # Controller for generating various reports in CSV and PDF formats
    class ReportsController < ActionController::Base
      def commissions_csv
        start_date, end_date = parse_date_range
        generate_csv(Reports::CommissionsReportService,
                     "commissions_#{format_date(start_date)}_to_#{format_date(end_date)}.csv")
      end

      def total_revenue_csv
        start_date, end_date = parse_date_range
        generate_csv(Reports::TotalRevenueReportService,
                     "total_revenue_#{format_date(start_date)}_to_#{format_date(end_date)}.csv")
      end

      def overdue_payments_csv
        start_date, end_date = parse_date_range
        generate_csv(Reports::OverduePaymentsReportService,
                     "overdue_payments_#{format_date(start_date)}_to_#{format_date(end_date)}.csv")
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
            render pdf: "user_balance_#{params[:user_id]}_#{timestamp}.pdf",
                   template: 'reports/user_balance',
                   formats: [:html],
                   layout: 'pdf',
                   disposition: 'attachment'
          end
        end
      rescue StandardError => e
        Rails.logger.error "Error generating User Balance PDF: #{e.message}"
        render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
      end

      def user_promise_contract_pdf
        financing_type = params[:financing_type].to_s
        service = Reports::UserPromiseContractService.new(params[:contract_id], financing_type)
        result = service.call

        return render json: { error: result[:error] }, status: :not_found unless result[:success]

        # Assign instance variables expected by the template
        @contract = result[:contract]
        @applicant = result[:applicant]
        @project = result[:project]
        @lot = result[:lot]
        @financing_amount = result[:financing_amount]
        @first_payment = result[:first_payment]
        @last_payment = result[:last_payment]

        respond_to do |format|
          format.pdf do
            render pdf: "promesa_compra_venta_#{params[:contract_id]}_#{timestamp}.pdf",
                   template: result[:template_name],
                   formats: [:html],
                   layout: 'pdf',
                   disposition: 'attachment'
          end
        end
      rescue StandardError => e
        Rails.logger.error "Error generating Promesa PDF: #{e.message}"
        render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
      end

      def user_rescission_contract_pdf
        service = Reports::UserRescissionContractService.new(params[:contract_id])
        result = service.call

        return render json: { error: result[:error] }, status: :not_found unless result[:success]

        @applicant = result[:applicant]
        @creator = result[:creator]
        @contract = result[:contract]
        @lot = result[:lot]
        @project = result[:project]
        @refund_amount = result[:refund_amount]
        @penalty_amount = result[:penalty_amount]
        @reservation_amount = result[:reservation_amount]

        respond_to do |format|
          format.pdf do
            render pdf: "rescision_contrato_#{params[:contract_id]}_#{timestamp}.pdf",
                   template: 'reports/rescission_contract',
                   formats: [:html],
                   layout: 'pdf',
                   disposition: 'attachment'
          end
        end
      rescue StandardError => e
        Rails.logger.error "Error generating Rescission Contract PDF: #{e.message}"
        render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
      end

      def user_information_pdf
        I18n.locale = params[:locale].to_s.downcase.to_sym if params[:locale].present? && %w[en
                                                                                             es].include?(params[:locale].downcase)

        service = Reports::UserInformationService.new(params[:contract_id])
        result = service.call

        return render json: { error: result[:error] }, status: :not_found unless result[:success]

        @applicant = result[:applicant]
        @contract = result[:contract]
        @lot = result[:lot]
        @project = result[:project]
        @payment = result[:payment]

        respond_to do |format|
          format.pdf do
            render pdf: "ficha_cliente_#{@applicant.id}_#{timestamp}.pdf",
                   template: 'reports/user_information',
                   formats: [:html],
                   layout: 'pdf',
                   disposition: 'attachment'
          end
        end
      rescue StandardError => e
        Rails.logger.error "Error generating User Information PDF: #{e.message}"
        render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
      end

      def currency_to_words(amount)
        NumberToWords.currency_a_letras(amount)
      end

      def number_to_words(amount)
        NumberToWords.numero_a_letras(amount)
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
                  filename:,
                  type: 'text/csv; charset=UTF-8; header=present',
                  disposition: 'attachment'
      end

      def timestamp
        Time.current.strftime('%Y%m%d_%H%M%S')
      end

      def format_date(date)
        Date.parse(date).strftime('%Y%m%d')
      end
    end
  end
end
