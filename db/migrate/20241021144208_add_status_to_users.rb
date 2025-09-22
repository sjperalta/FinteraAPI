# frozen_string_literal: true

# db/migrate/xxxxxx_add_status_to_users.rb
class AddStatusToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :status, :string, default: 'active'
  end
end
