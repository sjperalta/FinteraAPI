# frozen_string_literal: true

# db/migrate/20250926145040_add_indexes_to_payments.rb
class AddIndexesToPayments < ActiveRecord::Migration[8.0]
  def change
    add_index(:payments, :approved_at, if_not_exists: true)
    add_index(:payments, :created_at, if_not_exists: true)
    add_index(:payments, :payment_type, if_not_exists: true)
  end
end
