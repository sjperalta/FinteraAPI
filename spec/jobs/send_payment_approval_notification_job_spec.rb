# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendPaymentApprovalNotificationJob, type: :job do
  let(:payment) { instance_double('Payment', id: 42) }
  let(:notification_service) { instance_double('Notifications::PaymentApprovedEmailService') }

  before do
    # Stub Payment.find to return our double
    allow(Payment).to receive(:find).with(payment.id).and_return(payment)

    # Create a fake service class that accepts any args and returns our instance double
    payment_approved_class = double('Notifications::PaymentApprovedEmailServiceClass')
    allow(payment_approved_class).to receive(:new).with(any_args).and_return(notification_service)
    stub_const('Notifications::PaymentApprovedEmailService', payment_approved_class)

    allow(notification_service).to receive(:call)

    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    it 'finds the payment and calls the notification service' do
      expect(Payment).to receive(:find).with(payment.id)
      expect(Notifications::PaymentApprovedEmailService).to receive(:new).with(payment).and_return(notification_service)
      expect(notification_service).to receive(:call)

      described_class.perform_now(payment.id)
    end

    it 'raises ActiveRecord::RecordNotFound when payment not found' do
      allow(Payment).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      expect { described_class.perform_now(999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'enqueuing' do
    include ActiveJob::TestHelper

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    after { clear_enqueued_jobs }

    it 'enqueues the job with the payment id' do
      expect { described_class.perform_later(payment.id) }.to have_enqueued_job(described_class).with(payment.id)
    end
  end
end
