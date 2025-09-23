# frozen_string_literal: true

# Migration to add the password_digest column to the users table for password hashing.
class AddPasswordDigestToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :password_digest, :string
  end
end
