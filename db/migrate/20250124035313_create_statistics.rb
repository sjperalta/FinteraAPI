# frozen_string_literal: true

# Migration to create the statistics table for storing periodic financial and operational metrics.
class CreateStatistics < ActiveRecord::Migration[8.0]
  def change
    create_table :statistics do |t|
      t.date :period_date, null: false
      t.decimal :total_income, precision: 15, scale: 2, default: 0, null: false
      t.decimal :total_interest, precision: 15, scale: 2, default: 0, null: false
      t.integer :new_customers, default: 0, null: false
      t.decimal :payment_reserve, precision: 15, scale: 2, default: 0, null: false
      t.decimal :payment_installments, precision: 15, scale: 2, default: 0, null: false
      t.decimal :payment_down_payment, precision: 15, scale: 2, default: 0, null: false
      t.decimal :on_time_payment, precision: 15, scale: 2, default: 0, null: false
      t.decimal :delayed_payment, precision: 15, scale: 2, default: 0, null: false

      t.timestamps
    end

    # Add a unique index to ensure no duplicate statistics for the same period
    add_index :statistics, :period_date, unique: true
  end
end
