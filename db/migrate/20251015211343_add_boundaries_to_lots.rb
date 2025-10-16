# frozen_string_literal: true

class AddBoundariesToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :north, :text
    add_column :lots, :east, :text
    add_column :lots, :west, :text
  end
end
