# frozen_string_literal: true

# db/migrate/20250926150000_add_more_indexes.rb
# Adds additional indexes to optimize query performance on notifications, statistics, payments, and contracts tables.
class AddMoreIndexes < ActiveRecord::Migration[8.0]
  def change
    # notifications: composite index on (user_id, read_at)
    add_index :notifications, %i[user_id read_at], if_not_exists: true

    # statistics: index on created_at
    add_index :statistics, :created_at, if_not_exists: true

    # payments: index on status
    add_index :payments, :status, if_not_exists: true

    # payments: index on due_date
    add_index :payments, :due_date, if_not_exists: true

    # payments: composite index on (status, due_date)
    add_index :payments, %i[status due_date], if_not_exists: true

    # contracts: index on approved_at
    add_index :contracts, :approved_at, if_not_exists: true

    # contracts: composite index on (status, active)
    add_index :contracts, %i[status active], if_not_exists: true
  end
end
