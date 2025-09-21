require 'rails_helper'

RSpec.describe SendReservationApprovalNotificationJob, type: :job do
  let(:contract) { instance_double('Contract', id: 1, blank?: false) }
  let(:notification_service) { instance_double('Notifications::ReservationApprovalEmailService') }

  before do
    # Create a fake service class that accepts any args and returns our instance double
    reservation_approval_class = double('Notifications::ReservationApprovalEmailServiceClass')
    allow(reservation_approval_class).to receive(:new).with(any_args).and_return(notification_service)
    stub_const('Notifications::ReservationApprovalEmailService', reservation_approval_class)

    allow(notification_service).to receive(:call)

    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    context 'when contract present' do
      it 'calls the reservation approval email service' do
        expect(Notifications::ReservationApprovalEmailService).to receive(:new).with(contract).and_return(notification_service)
        expect(notification_service).to receive(:call)

        described_class.perform_now(contract)
      end
    end

    context 'when contract blank' do
      let(:contract) { nil }

      it 'returns early without calling the service' do
        expect(Notifications::ReservationApprovalEmailService).not_to receive(:new)

        described_class.perform_now(contract)
      end
    end
  end

  describe 'enqueuing' do
    include ActiveJob::TestHelper

    after { clear_enqueued_jobs }

    it 'can be enqueued with a serializable arg' do
      expect { described_class.perform_later(123) }.to have_enqueued_job(described_class).with(123)
    end
  end
end
