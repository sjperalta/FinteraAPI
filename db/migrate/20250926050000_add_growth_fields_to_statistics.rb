# frozen_string_literal: true

class AddGrowthFieldsToStatistics < ActiveRecord::Migration[8.0]
  def change
    add_column :statistics, :total_income_growth, :decimal, precision: 10, scale: 2, default: 0.0, if_not_exists: true
    add_column :statistics, :total_interest_growth, :decimal, precision: 10, scale: 2, default: 0.0, if_not_exists: true
    add_column :statistics, :new_customers_growth, :decimal, precision: 10, scale: 2, default: 0.0, if_not_exists: true
    add_column :statistics, :new_contracts_growth, :decimal, precision: 10, scale: 2, default: 0.0, if_not_exists: true
  end
end
