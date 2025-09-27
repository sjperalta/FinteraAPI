# frozen_string_literal: true

# app/models/contract_ledger_entry.rb
# Model representing ledger entries for contracts, tracking financial transactions and adjustments.
class ContractLedgerEntry < ApplicationRecord
  belongs_to :contract
  belongs_to :payment, optional: true

  validates :amount, presence: true, numericality: { other_than: 0 }
  validates :description, :entry_type, presence: true

  enum :entry_type, { due: 'due', payment: 'payment', interest: 'interest', adjustment: 'adjustment' }

  scope :by_date, -> { order(entry_date: :asc) }
  scope :debits, -> { where('amount > 0') }
  scope :credits, -> { where('amount < 0') }
  scope :balance, -> { select('SUM(amount) AS total_balance') }

  def self.total_balance
    balance.take.total_balance || 0
  end
end
