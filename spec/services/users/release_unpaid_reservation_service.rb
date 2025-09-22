require "rails_helper"

RSpec.describe Contracts::ReleaseUnpaidReservationService do
  describe "#notify_admin (private)" do
    let(:service) { described_class.new }

    it "notifies admins with the released count" do
      admin = double("User", id: 1)
      allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)

      expect(Notification).to receive(:create!).with(
        user: admin,
        title: "Contratos liberados",
        message: "1 contratos han sido cancelados y liberados debido a falta de pago de reserva.",
        notification_type: "contracts_released"
      )

      service.send(:notify_admin, 1)
    end

    it "does nothing when no admins present" do
      allow(User).to receive_message_chain(:where, :find_each).and_return([])

      expect(Notification).not_to receive(:create!)

      service.send(:notify_admin, 2)
    end

    it "logs error when notification creation fails" do
      admin = double("User", id: 2)
      allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)
      allow(Notification).to receive(:create!).and_raise(StandardError.new("boom"))

      expect(Rails.logger).to receive(:error).with(/Failed to create notification: boom/)

      service.send(:notify_admin, 3)
    end
  end
end
