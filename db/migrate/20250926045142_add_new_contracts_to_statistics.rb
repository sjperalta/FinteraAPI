# frozen_string_literal: true

class AddNewContractsToStatistics < ActiveRecord::Migration[8.0]
  def change
    add_column(:statistics, :new_contracts, :integer, if_not_exists: true)
  end
end
