# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :contract, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :paid_amount, precision: 15, scale: 2, default: 0.0
      t.date :due_date, null: false
      t.date :payment_date
      t.string :status, null: false, default: 'pending'
      t.string :payment_type, default: 'installment'
      t.string :description
      t.decimal :interest_amount, precision: 10, scale: 2
      t.datetime :approved_at

      t.timestamps
    end
  end
end
