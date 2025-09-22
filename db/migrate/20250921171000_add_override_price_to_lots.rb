# frozen_string_literal: true

class AddOverridePriceToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :override_price, :decimal, precision: 15, scale: 2
  end
end
