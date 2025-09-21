require 'rails_helper'

RSpec.describe NotifyAdminPaymentReceiptJob, type: :job do
  include ActiveJob::TestHelper

  after { clear_enqueued_jobs }

  it 'enqueues on the default queue' do
    payment = double('Payment', id: 1)

    expect(NotifyAdminPaymentReceiptJob).to receive(:perform_later).with(payment)
    NotifyAdminPaymentReceiptJob.perform_later(payment)
  end

  it 'calls the admin notification service with the payment' do
    payment = double('Payment', id: 1)
    service = instance_double('Notifications::AdminPaymentReceiptNotificationService')
    expect(Notifications::AdminPaymentReceiptNotificationService).to receive(:new).with(payment).and_return(service)
    expect(service).to receive(:call)

    NotifyAdminPaymentReceiptJob.perform_now(payment)
  end
end
