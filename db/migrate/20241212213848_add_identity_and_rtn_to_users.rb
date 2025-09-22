# frozen_string_literal: true

class AddIdentityAndRtnToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :identity, :string
    add_column :users, :rtn, :string

    # Optional: Add indexes if you need to query these fields frequently
    add_index :users, :identity, unique: true
    add_index :users, :rtn, unique: true
  end
end
