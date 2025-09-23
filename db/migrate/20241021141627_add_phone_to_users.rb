# frozen_string_literal: true

# Migration to add the phone column to the users table.
class AddPhoneToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :phone, :string
  end
end
