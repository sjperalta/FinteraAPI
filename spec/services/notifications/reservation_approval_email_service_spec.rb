# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::ReservationApprovalEmailService, type: :service do
  let(:user) { instance_double('User', email: 'user@example.com', full_name: 'Test User') }
  let(:contract) { double('Contract', id: 7, applicant_user: user, project: nil, lot: nil, reserve_amount: 1000) }

  before do
    @mailer = double('UserMailer')
    @mailer_action = double('MailerAction', deliver_now: true)
    allow(@mailer).to receive(:reservation_approved).and_return(@mailer_action)
    allow(UserMailer).to receive(:with).with(user:, contract:).and_return(@mailer)
  end

  it 'sends reservation approved email when user present' do
    expect(UserMailer).to receive(:with).with(user:, contract:)
    expect(@mailer).to receive(:reservation_approved).and_return(@mailer_action)
    expect(@mailer_action).to receive(:deliver_now)

    described_class.new(contract).call
  end

  it 'does nothing when contract has no user' do
    contract_without_user = double('Contract', id: 8, applicant_user: nil)
    expect(UserMailer).not_to receive(:with)

    described_class.new(contract_without_user).call
  end
end
