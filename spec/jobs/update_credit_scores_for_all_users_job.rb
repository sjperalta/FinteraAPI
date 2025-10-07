# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateCreditScoresForAllUsersJob, type: :job do
  let(:active_user) do
    user = User.new(
      email: 'active.user@example.com',
      full_name: 'Active User',
      phone: '0000000000',
      password: 'password123',
      password_confirmation: 'password123',
      identity: '1234567890',
      rtn: '1234567890',
      role: 'user',
      confirmed_at: Time.current
    )
    user.save!
    user
  end
  let(:discarded_user) do
    user = User.new(
      email: 'discarded.user@example.com',
      full_name: 'Discarded User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '0000000001',
      identity: '1234567891',
      rtn: '1234567891',
      role: 'user',
      confirmed_at: Time.current
    )
    user.save!
    user.discard
    user
  end
  let(:admin_user) do
    user = User.new(
      email: 'admin@example.com',
      full_name: 'Admin User',
      phone: '0000000002',
      password: 'password123',
      password_confirmation: 'password123',
      identity: '1234567892',
      rtn: '1234567892',
      role: 'admin',
      confirmed_at: Time.current
    )
    user.save!
    user
  end

  it 'updates credit scores only for active users with role user' do
    allow(active_user).to receive(:update_credit_score)
    expect(active_user).to receive(:update_credit_score).once

    query = double
    query2 = double
    allow(User).to receive(:where).and_return(query)
    allow(query).to receive(:kept).and_return(query2)
    allow(query2).to receive(:find_each).and_yield(active_user)

    described_class.perform_now
  end

  it 'does not update credit scores for discarded users or non-user roles' do
    expect(discarded_user).not_to receive(:update_credit_score)
    expect(admin_user).not_to receive(:update_credit_score)

    query = double
    query2 = double
    allow(User).to receive(:where).and_return(query)
    allow(query).to receive(:kept).and_return(query2)
    allow(query2).to receive(:find_each).and_return([])

    described_class.perform_now
  end
end
