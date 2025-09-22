# frozen_string_literal: true

class AddCreatedByToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :created_by, :bigint unless column_exists?(:users, :created_by)

    add_foreign_key :users, :users, column: :created_by unless foreign_key_exists?(:users, column: :created_by)

    return if index_exists?(:users, :created_by)

    add_index :users, :created_by
  end
end
