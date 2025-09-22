# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendContractApprovalNotificationJob, type: :job do
  let(:contract) { instance_double('Contract', id: 1, blank?: false) }
  let(:notification_service) { instance_double('Notifications::ContractApprovalEmailService') }

  before do
    # Create a fake class-like object that responds to `.new` with any args
    contract_approval_class = double('Notifications::ContractApprovalEmailServiceClass')
    allow(contract_approval_class).to receive(:new).with(any_args).and_return(notification_service)
    stub_const('Notifications::ContractApprovalEmailService', contract_approval_class)
    allow(notification_service).to receive(:call)
  end

  describe '#perform' do
    context 'when contract is present' do
      it 'calls the contract approval email service' do
        expect(Notifications::ContractApprovalEmailService).to receive(:new).with(contract)
        expect(notification_service).to receive(:call)

        described_class.perform_now(contract)
      end
    end

    context 'when contract is blank' do
      let(:contract) { nil }

      it 'returns early without calling the service' do
        expect(Notifications::ContractApprovalEmailService).not_to receive(:new)

        described_class.perform_now(contract)
      end
    end

    context 'when contract is an empty object' do
      let(:contract) { instance_double('Contract', blank?: true) }

      it 'returns early without calling the service' do
        expect(Notifications::ContractApprovalEmailService).not_to receive(:new)

        described_class.perform_now(contract)
      end
    end
  end

  describe 'enqueuing' do
    include ActiveJob::TestHelper

    let(:serializable_contract_arg) { 123 }

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    after { clear_enqueued_jobs }

    it 'can be enqueued with a serializable contract arg' do
      expect do
        described_class.perform_later(serializable_contract_arg)
      end.to have_enqueued_job(described_class).with(serializable_contract_arg)
    end

    it 'is queued on the default queue' do
      described_class.perform_later(serializable_contract_arg)
      expect(described_class).to have_been_enqueued.on_queue('default')
    end
  end
end
