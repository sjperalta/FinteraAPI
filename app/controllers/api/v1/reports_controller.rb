require 'csv'

class Api::V1::ReportsController < ApplicationController

  # GET /api/v1/reports/commissions_csv?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
  def commissions_csv
    start_date, end_date = parse_date_range

    # 1. Query for approved contracts within date range based on 'approved_at'
    contracts = Contract
      .where(status: 'approved')
      .where(approved_at: start_date..end_date)
      .includes(:creator, :lot)

    # 2. Generate CSV
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "Id Usuario",        # => c.creator_id
        "Nombre Completo",   # => creator.full_name
        "Fecha",             # => c.approved_at
        "Descripción",       # => c.description
        "Cantidad", # => c.amount
        "% Comisión", # => c.commission_rate
        "Comisión Total"       # => c.amount * c.commission_rate
      ]

      contracts.each do |c|
        full_name         = c.creator&.full_name || "N/A"
        commission_rate   = c.lot.project.commission_rate || 0
        total_commission  = (c.amount * (commission_rate / 100)).round(2)
        csv << [
          c.creator_id,
          full_name,
          c.approved_at,
          "#{c.lot.project.name} - #{c.lot.name}",
          c.amount,
          "#{commission_rate} %",
          total_commission
        ]
      end
    end

    send_data csv_data,
              filename: "commissions_report.csv",
              type: "text/csv; charset=UTF-8; header=present",
              disposition: "attachment"
  end

  # GET /api/v1/reports/total_revenue_csv?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
  def total_revenue_csv
    start_date, end_date = parse_date_range

    # Example: "Approved" payments in date range (by payment_date)
    payments = Payment
      .where(status: 'paid')
      .where(payment_date: start_date..end_date)

    total_paid     = payments.sum(:paid_amount).to_f
    total_interest = payments.sum(:interest_amount).to_f
    grand_total    = total_paid + total_interest

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["ID Pago", "Description", "Paid Amount", "Interest Amount", "Due Date", "Payment Date"]
      payments.each do |p|
        csv << [
          p.id,
          p.description,
          p.paid_amount.to_f,
          p.interest_amount.to_f,
          p.due_date,
          p.payment_date
        ]
      end

      csv << []
      csv << ["Summary"]
      csv << ["Total Paid", total_paid]
      csv << ["Total Interest", total_interest]
      csv << ["Grand Total", grand_total]
    end

    send_data csv_data,
              filename: "total_revenue_report.csv",
              type: "text/csv; charset=UTF-8; header=present",
              disposition: "attachment"
  end

  # GET /api/v1/reports/overdue_payments_csv?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
  def overdue_payments_csv
    start_date, end_date = parse_date_range

    # Overdue payments => status='pending', due_date < today
    # Also filter by date range if you want to restrict e.g. created_at or payment_date
    # For a date range on due_date itself, do something like:
    #    .where(due_date: start_date..end_date)
    overdue_payments = Payment
      .joins(contract: :applicant_user)
      .where(status: 'pending')
      .where(due_date: start_date..end_date)  # Adjust if you want to filter the range
      .where("payments.due_date < ?", Date.current)

    # Summaries
    total_amount   = overdue_payments.sum(:amount).to_f
    total_interest = overdue_payments.sum(:interest_amount).to_f

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "Id Pago",      # p.id
        "Nombre Completo", # user.full_name
        "Email",        # user.email
        "Telefono",     # user.phone
        "Descripcion",  # p.description
        "Cantidad",     # p.amount
        "Intereses",    # p.interest_amount
        "Fecha de Pago",# p.payment_date or p.due_date?
        "Dias de Mora"  # e.g. Date.current - p.due_date
      ]

      overdue_payments.each do |p|
        user = p.contract.applicant_user
        overdue_days = (Date.current - p.due_date).to_i
        csv << [
          p.id,
          user&.full_name,
          user&.email,
          user&.phone,
          p.description,
          p.amount.to_f,
          p.interest_amount.to_f,
          p.due_date,   # or p.due_date, whichever is "Fecha de Pago"
          overdue_days - 1
        ]
      end

      csv << []
      csv << ["Summary"]
      csv << ["Total Cantidad", total_amount]
      csv << ["Total Intereses", total_interest]
    end

    send_data csv_data,
              filename: "overdue_payments_report.csv",
              type: "text/csv; charset=UTF-8; header=present",
              disposition: "attachment"
  end

  private

  # Utility method to parse start_date/end_date from params
  # Defaults to the current month's range if none provided
  def parse_date_range
    s = params[:start_date].presence || Date.current.beginning_of_month.to_s
    e = params[:end_date].presence   || Date.current.end_of_month.to_s
    [s, e]
  end
end
