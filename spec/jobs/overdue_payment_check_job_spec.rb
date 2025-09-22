# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckPaymentsOverdueJob, type: :job do
  include ActiveJob::TestHelper

  after { clear_enqueued_jobs }

  it 'schedules the job via perform_later' do
    expect(CheckPaymentsOverdueJob).to receive(:perform_later)
    CheckPaymentsOverdueJob.perform_later
  end

  it 'finds overdue payments and notifies users' do
    user1 = double('User', id: 1)
    user2 = double('User', id: 2)

    contract1 = double('Contract', applicant_user: user1)
    contract2 = double('Contract', applicant_user: user2)

    payment1 = double('Payment', contract: contract1)
    payment2 = double('Payment', contract: contract1)
    payment3 = double('Payment', contract: contract2)

    # Stub the ActiveRecord chain to return our payments
    payments_relation = [payment1, payment2, payment3]
    allow(Payment).to receive_message_chain(:joins, :where).and_return(payments_relation)

    service1 = instance_double('Notifications::OverduePaymentEmailService')
    service2 = instance_double('Notifications::OverduePaymentEmailService')

    expect(Notifications::OverduePaymentEmailService).to receive(:new).with(user1,
                                                                            [payment1, payment2]).and_return(service1)
    expect(service1).to receive(:call)

    expect(Notifications::OverduePaymentEmailService).to receive(:new).with(user2, [payment3]).and_return(service2)
    expect(service2).to receive(:call)

    CheckPaymentsOverdueJob.new.perform
  end
end
