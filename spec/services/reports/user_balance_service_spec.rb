# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::UserBalanceService do
  it 'calculates balance and notifies admin' do
    payments_double = double('Payments')
    allow(payments_double).to receive(:sum).with(:amount).and_return(150.0)
    allow(payments_double).to receive(:sum).with(:paid_amount).and_return(50.0)

    pending_double = double('Pending')
    allow(pending_double).to receive(:overdue).and_return([])
    allow(payments_double).to receive(:pending).and_return(pending_double)

    user = double('User', payments: payments_double, full_name: 'Test User')
    admin = double('Admin')
    allow(User).to receive(:find_by).with(id: 1).and_return(user)
    allow(User).to receive(:find_by).with(role: 'admin').and_return(admin)

    expect(Notification).to receive(:create).with(hash_including(user: admin))

    result = described_class.new(1).call
    expect(result[:success]).to be_truthy
    expect(result[:balance]).to eq(100.0) # 150 - 50
  end
end
