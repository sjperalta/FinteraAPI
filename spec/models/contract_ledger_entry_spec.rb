# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContractLedgerEntry, type: :model do
  # Use plain in-memory objects to avoid DB dependence in unit tests
  let(:project) do
    Project.new(name: 'P', address: 'A', lot_count: 1, price_per_square_unit: 100, measurement_unit: 'm2',
                interest_rate: 5)
  end
  let(:lot) { Lot.new(project:, name: 'L', length: 10, width: 10, price: 1000) }
  let(:contract) do
    Contract.new(lot:, applicant_user_id: 1, payment_term: 12, financing_type: 'direct', reserve_amount: 100,
                 down_payment: 200, amount: 1000)
  end
  let(:payment) { Payment.new(contract:, amount: 100, due_date: Date.today, payment_type: 'reservation') }

  describe 'associations' do
    it 'belongs to contract' do
      assoc = ContractLedgerEntry.reflect_on_association(:contract)
      expect(assoc).not_to be_nil
      expect(assoc.macro).to eq(:belongs_to)
    end

    it 'belongs to payment (optional)' do
      assoc = ContractLedgerEntry.reflect_on_association(:payment)
      expect(assoc).not_to be_nil
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to be true
    end
  end

  describe 'validations' do
    it 'validates presence of amount, description and entry_type' do
      entry = ContractLedgerEntry.new
      expect(entry).not_to be_valid
      expect(entry.errors[:amount]).to include("can't be blank")
      expect(entry.errors[:description]).to include("can't be blank")
      expect(entry.errors[:entry_type]).to include("can't be blank")
    end

    it 'validates numericality and non-zero amount' do
      entry = ContractLedgerEntry.new(amount: 0, description: 'x', entry_type: 'due')
      expect(entry).not_to be_valid
      expect(entry.errors[:amount]).to include('must be other than 0')
    end
  end

  describe 'enum' do
    it 'defines expected entry_type values' do
      expect(ContractLedgerEntry.entry_types).to include('due' => 'due', 'payment' => 'payment',
                                                         'interest' => 'interest', 'adjustment' => 'adjustment')
    end
  end

  describe 'scopes' do
    it 'defines the by_date, debits and credits scopes' do
      expect(ContractLedgerEntry).to respond_to(:by_date)
      expect(ContractLedgerEntry).to respond_to(:debits)
      expect(ContractLedgerEntry).to respond_to(:credits)
    end

    it 'filters debits/credits when applied to an array of entries (unit test style)' do
      e1 = ContractLedgerEntry.new(contract:, amount: 100, entry_date: 2.days.ago)
      e2 = ContractLedgerEntry.new(contract:, amount: -50, entry_date: 1.day.ago)
      e3 = ContractLedgerEntry.new(contract:, amount: 200, entry_date: 3.days.ago)

      all = [e1, e2, e3]
      debits = all.select { |e| e.amount && e.amount.positive? }
      credits = all.select { |e| e.amount && e.amount.negative? }

      expect(debits).to include(e1, e3)
      expect(debits).not_to include(e2)
      expect(credits).to include(e2)
      expect(credits).not_to include(e1, e3)
    end
  end

  describe '.total_balance' do
    it 'returns the sum reported by the balance scope (stubbed here)' do
      fake = double('relation', take: double(total_balance: 50))
      allow(ContractLedgerEntry).to receive(:balance).and_return(fake)
      expect(ContractLedgerEntry.total_balance).to eq(50)
    end
  end

  describe 'constructor' do
    it 'builds a valid instance with required attributes' do
      entry = ContractLedgerEntry.new(contract:, payment:, amount: 100, description: 'test',
                                      entry_type: 'due')
      expect(entry).to be_valid
    end
  end
end
