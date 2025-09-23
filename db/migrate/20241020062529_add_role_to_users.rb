# frozen_string_literal: true

# Migration to add the role column to the users table for role-based authorization.
class AddRoleToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :role, :string, default: 'user'
  end
end
