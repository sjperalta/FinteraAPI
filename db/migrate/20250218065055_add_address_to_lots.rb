# frozen_string_literal: true

# Migration to add the address column to the lots table.
class AddAddressToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :address, :string
  end
end
