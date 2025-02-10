class Api::V1::StatisticsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource

  def index
    # Extract month and year from query parameters; they will be nil if not provided.
    month = params[:month]
    year  = params[:year]

    # Call the service with the provided parameters (or default values)
    statistics = Statistics::FetchMonthStatisticsService.call(month: month, year: year)

    render json: statistics
  end

  def monthly_revenue
    year = params[:year].to_i
    if year < 2000 || year > Date.today.year
      render json: { error: "Invalid year" }, status: :bad_request
      return
    end

    datasets = ["reservation", "down_payment", "installment"].map do |payment_type|
      {
        label: payment_type.capitalize,
        data: (1..12).map do |month|
          Revenue.find_by(payment_type: payment_type, year: year, month: month)&.amount || 0.0
        end,
        backgroundColor: case payment_type
                         when "reservation" then "rgba(250, 204, 21, 1)"
                         when "down_payment" then "rgba(74, 222, 128, 1)"
                         when "installment" then "rgba(255, 120, 75, 1)"
                         end
      }
    end

    render json: { year: year, datasets: datasets }
  end
end
