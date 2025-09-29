require 'rails_helper'

# simple proxy to mimic ActiveRecord association methods used by the service
ContractsProxy = Class.new(Array) do
  def includes(*)
    self
  end
end

RSpec.describe CreditScore::CreditScoreCalculator, type: :service do
  describe '#calculate' do
    it 'returns 40 and updates user credit_score when user has no contracts' do
      user = double('User')

      contracts = ContractsProxy.new([])

      allow(user).to receive(:contracts).and_return(contracts)

      expect(user).to receive(:update).with(credit_score: 40)

      calculator = described_class.new(user)
      expect(calculator.calculate).to eq 40
    end

    it 'calculates score from payment history, utilization, age and accounts and updates user' do
      user = double('User')

      payment_on_time = double('Payment', due_date: Date.today, payment_date: Date.today)
      payment_late = double('Payment', due_date: Date.today, payment_date: Date.today + 1)

      contract = double('Contract', payments: [payment_on_time, payment_late], amount: 1000.0, balance: 500.0,
                                    created_at: 2.years.ago)

      contracts = ContractsProxy.new([contract])

      allow(user).to receive(:contracts).and_return(contracts)

      # Expected computation from the service:
      # payment_history = 50 (1/2 on time) -> *0.40 = 20
      # credit_utilization = (500/1000)*100 = 50 -> *0.20 = 10
      # credit_age = 2.0 -> *0.21 = 0.42
      # total_accounts = 1 -> *0.19 = 0.19
      # total = 20 + 10 + 0.42 + 0.19 = 30.61 -> round -> 31

      expect(user).to receive(:update).with(credit_score: 31)

      calculator = described_class.new(user)
      expect(calculator.calculate).to eq 31
    end
  end
end
