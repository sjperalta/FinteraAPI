# frozen_string_literal: true

# db/migrate/20250927183148_add_credit_score_to_users.rb
# Migration to add credit_score column to users table
class AddCreditScoreToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :credit_score, :integer, if_not_exists: true, default: 0, null: false
  end
end
