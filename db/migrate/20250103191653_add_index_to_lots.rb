# frozen_string_literal: true

class AddIndexToLots < ActiveRecord::Migration[7.0]
  def change
    add_index :lots, :name
    add_index :users, :full_name
    add_index :projects, :name
    add_index :lots, :status
  end
end
