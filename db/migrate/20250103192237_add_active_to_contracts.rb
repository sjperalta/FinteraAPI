# frozen_string_literal: true

# Migration to add the active column to contracts table for soft deletion functionality.
class AddActiveToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :active, :boolean, default: false, null: false
    add_index :contracts, :active
  end
end
