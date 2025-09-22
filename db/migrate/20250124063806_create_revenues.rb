# frozen_string_literal: true

class CreateRevenues < ActiveRecord::Migration[8.0]
  def change
    create_table :revenues do |t|
      t.string :payment_type, null: false # "reserva", "prima", or "cuotas"
      t.integer :year, null: false       # Year of the revenue
      t.integer :month, null: false      # Month of the revenue
      t.decimal :amount, precision: 15, scale: 2, default: 0.0 # Revenue amount

      t.timestamps
    end

    # Add an index for quick lookups
    add_index :revenues, %i[payment_type year month], unique: true
  end
end
