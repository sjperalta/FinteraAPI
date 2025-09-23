# frozen_string_literal: true

# Migration to add the full_name column to the users table.
class AddFullNameToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :full_name, :string
  end
end
