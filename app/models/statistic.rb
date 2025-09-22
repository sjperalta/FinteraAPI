# frozen_string_literal: true

# app/models/statistic.rb

class Statistic < ApplicationRecord
  validates :period_date, presence: true, uniqueness: true
  validates :total_income, :total_interest, :payment_reserve, :payment_installments, :payment_down_payment,
            numericality: { greater_than_or_equal_to: 0 }
  validates :new_customers, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scope to find statistics for a specific period
  scope :for_period, ->(start_date, end_date) { where(period_date: start_date..end_date) }

  # Example method to calculate total payments for a range of dates
  def self.total_payments_for_period(start_date, end_date)
    for_period(start_date, end_date).sum('payment_reserve + payment_installments + payment_down_payment')
  end
end
