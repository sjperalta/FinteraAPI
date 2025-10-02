# frozen_string_literal: true

# Migration to add payment_capital_repayment column to statistics table
# This column will store the total capital repayment amounts for each month.
class AddPaymentCapitalRepaymentToStatistics < ActiveRecord::Migration[8.0]
  def change
    add_column :statistics, :payment_capital_repayment, :decimal
  end
end
