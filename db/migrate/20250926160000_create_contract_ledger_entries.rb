# frozen_string_literal: true

# db/migrate/20250926160000_create_contract_ledger_entries.rb
# # Migration to create the contract_ledger_entries table for tracking contract financial entries.
class CreateContractLedgerEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_ledger_entries do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :payment, null: true, foreign_key: true
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :description, null: false
      t.string :entry_type, null: false # e.g., 'reservation', 'down_payment', 'installment', 'interest', 'adjustment'
      t.datetime :entry_date, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end
    add_index :contract_ledger_entries, %i[contract_id entry_date], if_not_exists: true
  end
end
