# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckPaymentsOverdueJob, type: :job do
  describe '#perform' do
    let(:user) { instance_double('User', present?: true) }
    let(:contract) { instance_double('Contract', applicant_user: user) }
    let(:payment1) { instance_double('Payment', contract:) }
    let(:payment2) { instance_double('Payment', contract:) }

    before do
      # create a class-like double to stub .new calls
      overdue_notifier_class = double('Notifications::OverduePaymentEmailServiceClass')
      stub_const('Notifications::OverduePaymentEmailService', overdue_notifier_class)
    end

    it 'groups overdue payments by user and calls the notification service' do
      allow(Payment).to receive_message_chain(:joins, :where).and_return([payment1, payment2])

      service = instance_double('Notifications::OverduePaymentEmailService', call: true)
      expect(Notifications::OverduePaymentEmailService).to receive(:new).with(user,
                                                                              [payment1, payment2]).and_return(service)
      expect(service).to receive(:call)

      described_class.new.perform
    end

    it 'does nothing when there are no overdue payments' do
      allow(Payment).to receive_message_chain(:joins, :where).and_return([])

      expect(Notifications::OverduePaymentEmailService).not_to receive(:new)
      expect { described_class.new.perform }.not_to raise_error
    end

    it 'skips notifications for payments whose contract has no applicant_user' do
      contract_without_user = instance_double('Contract', applicant_user: nil)
      payment = instance_double('Payment', contract: contract_without_user)
      allow(Payment).to receive_message_chain(:joins, :where).and_return([payment])

      expect(Notifications::OverduePaymentEmailService).not_to receive(:new)
      expect { described_class.new.perform }.not_to raise_error
    end
  end
end

RSpec.describe SendPaymentApprovalNotificationJob, type: :job do
  describe '#perform' do
    let(:payment_id) { 42 }
    let(:payment) { instance_double('Payment', id: payment_id) }

    before do
      payment_approved_class = double('Notifications::PaymentApprovedEmailServiceClass')
      stub_const('Notifications::PaymentApprovedEmailService', payment_approved_class)
    end

    it 'builds and calls the payment approved notification service for a given payment id' do
      expect(Payment).to receive(:find).with(payment_id).and_return(payment)

      service = instance_double('Notifications::PaymentApprovedEmailService', call: true)
      expect(Notifications::PaymentApprovedEmailService).to receive(:new).with(payment).and_return(service)
      expect(service).to receive(:call)

      described_class.new.perform(payment_id)
    end

    it 'does not raise when payment is not found' do
      expect(Payment).to receive(:find).with(payment_id).and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.new.perform(payment_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

RSpec.describe SendContractApprovalNotificationJob, type: :job do
  describe '#perform' do
    let(:contract) { instance_double('Contract', id: 99, applicant_user: instance_double('User')) }

    before do
      contract_approval_class = double('Notifications::ContractApprovalEmailServiceClass')
      stub_const('Notifications::ContractApprovalEmailService', contract_approval_class)
    end

    it 'invokes the contract approval notification service' do
      service = instance_double('Notifications::ContractApprovalEmailService', call: true)
      expect(Notifications::ContractApprovalEmailService).to receive(:new).with(contract).and_return(service)
      expect(service).to receive(:call)

      described_class.new.perform(contract)
    end

    it 'safely handles missing contract record (nil passed)' do
      # If job is invoked with nil, it should not attempt to call the service
      expect(Notifications::ContractApprovalEmailService).not_to receive(:new)
      expect { described_class.new.perform(nil) }.not_to raise_error
    end
  end
end

RSpec.describe GenerateRevenueJob, type: :job do
  describe '#perform' do
    before do
      revenue_service = double('Statistics::RevenueService')
      stub_const('Statistics::RevenueService', revenue_service)
    end

    it 'invokes the revenue generation' do
      expect(Statistics::RevenueService).to receive(:generate_for_current_month)
      described_class.new.perform
    end
  end
end

RSpec.describe GenerateStatisticsJob, type: :job do
  describe '#perform' do
    let(:period_date) { Date.today }

    before do
      stats_class = double('Statistics::GenerateStatisticsServiceClass')
      stub_const('Statistics::GenerateStatisticsService', stats_class)
    end

    it 'calls the statistics service' do
      service = instance_double('Statistics::GenerateStatisticsService', call: true)
      expect(Statistics::GenerateStatisticsService).to receive(:new).with(period_date).and_return(service)
      expect(service).to receive(:call)

      described_class.new.perform(period_date)
    end

    it 'raises when the service fails' do
      service = instance_double('Statistics::GenerateStatisticsService')
      expect(Statistics::GenerateStatisticsService).to receive(:new).with(period_date).and_return(service)
      expect(service).to receive(:call).and_raise(StandardError.new('stats fail'))

      expect { described_class.new.perform(period_date) }.to raise_error(StandardError, 'stats fail')
    end
  end
end
