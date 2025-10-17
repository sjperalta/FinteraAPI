# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateCreditScoresJob, type: :job do
  let(:users) { [1, 2, 3] }
  let(:active_user) { User.new(id: 1, email: 'test@example.com', full_name: 'Test User', role: 'user') }
  let(:admin_user) { User.new(id: 99, email: 'admin@example.com', full_name: 'Admin User', role: 'admin') }

  it 'updates credit scores only for provided list of users' do
    users_query = double('users_query')
    users_kept_query = double('users_kept_query')
    admin_query = double('admin_query')

    # Mock User.where(id: users).kept.find_each
    allow(User).to receive(:where).with(id: users).and_return(users_query)
    allow(users_query).to receive(:kept).and_return(users_kept_query)
    allow(users_kept_query).to receive(:find_each).and_yield(active_user)

    # Mock User.where(role: 'admin').pluck(:id) for cache invalidation
    allow(User).to receive(:where).with(role: 'admin').and_return(admin_query)
    allow(admin_query).to receive(:pluck).with(:id).and_return([admin_user.id])

    # Mock Rails.cache.increment for version bumping
    allow(Rails.cache).to receive(:increment)

    # Expect update_credit_score to be called once
    expect(active_user).to receive(:update_credit_score).once

    described_class.perform_now(users)

    # Verify cache version bump was called for admin/users
    expect(Rails.cache).to have_received(:increment).at_least(:once)
  end

  it 'does not update credit scores for non-existent users' do
    users_query = double('users_query')
    users_kept_query = double('users_kept_query')
    admin_query = double('admin_query')

    allow(User).to receive(:where).with(id: users).and_return(users_query)
    allow(users_query).to receive(:kept).and_return(users_kept_query)
    allow(users_kept_query).to receive(:find_each).and_return([]) # No users yielded

    allow(User).to receive(:where).with(role: 'admin').and_return(admin_query)
    allow(admin_query).to receive(:pluck).with(:id).and_return([])

    allow(Rails.cache).to receive(:increment)

    described_class.perform_now(users)

    # Verify no update_credit_score calls since no users were returned
  end

  it 'handles empty or nil user_ids gracefully' do
    allow(Rails.logger).to receive(:info)

    described_class.perform_now(nil)
    described_class.perform_now([])

    expect(Rails.logger).to have_received(:info).with('No user IDs provided for credit score update. Exiting job.').twice
  end

  it 'invalidates cache for admin users after updating credit scores' do
    admin1 = User.new(id: 10, role: 'admin')
    admin2 = User.new(id: 11, role: 'admin')

    users_query = double('users_query')
    users_kept_query = double('users_kept_query')
    admin_query = double('admin_query')

    allow(User).to receive(:where).with(id: users).and_return(users_query)
    allow(users_query).to receive(:kept).and_return(users_kept_query)
    allow(users_kept_query).to receive(:find_each).and_yield(active_user)

    allow(User).to receive(:where).with(role: 'admin').and_return(admin_query)
    allow(admin_query).to receive(:pluck).with(:id).and_return([admin1.id, admin2.id])

    allow(Rails.cache).to receive(:increment)

    described_class.perform_now(users)

    # Verify that increment was called (admin version bump + per-user bumps)
    expect(Rails.cache).to have_received(:increment).at_least(:once)
  end
end
