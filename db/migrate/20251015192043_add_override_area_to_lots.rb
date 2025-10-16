# frozen_string_literal: true

class AddOverrideAreaToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :override_area, :decimal
  end
end
