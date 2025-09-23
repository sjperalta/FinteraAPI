# frozen_string_literal: true

# Migration to add discarded_at column to users table for soft deletion using the discard gem.
class AddDiscardedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :discarded_at, :datetime
    add_index :users, :discarded_at
  end
end
