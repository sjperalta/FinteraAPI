require 'rails_helper'

RSpec.describe UpdateCreditScoresJob, type: :job do
  let(:users) { [1, 2, 3] }
  let(:active_user) { double('User', id: 1, update_credit_score: true) }

  it 'updates credit scores only for provided list of users' do
    allow(active_user).to receive(:update_credit_score)
    expect(active_user).to receive(:update_credit_score).once

    query = double
    query2 = double
    allow(User).to receive(:where).with(id: users).and_return(query)
    allow(query).to receive(:kept).and_return(query2)
    allow(query2).to receive(:find_each).and_yield(active_user)

    described_class.perform_now(users)
  end

  it 'does not update credit scores for non-existent users' do
    query = double('query')
    query2 = double('query2')

    allow(User).to receive(:where).with(id: users).and_return(query)
    allow(query).to receive(:kept).and_return(query2)
    allow(query2).to receive(:find_each).and_return([]) # No users yielded

    described_class.perform_now(users)
  end

  it 'handles empty or nil user_ids gracefully' do
    # Use a spy so any other logger calls (e.g. from integrations) don't break this test
    allow(Rails.logger).to receive(:info)

    described_class.perform_now(nil)
    described_class.perform_now([])

    expect(Rails.logger).to have_received(:info).with('No user IDs provided for credit score update. Exiting job.').twice
  end
end
