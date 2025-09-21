require 'rails_helper'

RSpec.describe NotifyAdminPaymentReceiptJob, type: :job do
  include ActiveJob::TestHelper

  after { clear_enqueued_jobs }

  it 'enqueues on the default queue' do
    expect(NotifyAdminPaymentReceiptJob).to receive(:perform_later).with(1)
    NotifyAdminPaymentReceiptJob.perform_later(1)
  end

  it 'calls the admin notification service with the payment' do
    payment = instance_double('Payment', id: 1)
    service = instance_double('Notifications::AdminPaymentReceiptNotificationService')
    allow(Payment).to receive(:find_by).with(id: 1).and_return(payment)
    expect(Notifications::AdminPaymentReceiptNotificationService).to receive(:new).with(payment).and_return(service)
    expect(service).to receive(:call)

    NotifyAdminPaymentReceiptJob.perform_now(1)
  end
end
