require "rails_helper"

RSpec.describe Contracts::ReleaseUnpaidReservationService do
  let(:service) { described_class.new }

  describe "#call" do
    it "processes unpaid reservation payments and notifies admins when contracts are released" do
      admin = double("User", id: 1)
      contract = double(
        "Contract",
        id: 42,
        lot: double("Lot", name: "Lote 1")
      )

      # allow assignment and persistence calls performed by the service
      allow(contract).to receive(:rejection_reason=)
      allow(contract).to receive(:save!).and_return(true)

      # contract.payments.where(...).where.not(...).empty? => true (no processed reservation payments)
      allow(contract).to receive_message_chain(:payments, :where, :where, :not, :empty?).and_return(true)

      # AASM guards and transitions are exercised by stubbing the predicate and action methods
      allow(contract).to receive(:may_reject?).and_return(true)
      allow(contract).to receive(:reject!).and_return(true)
      allow(contract).to receive(:may_cancel?).and_return(true)
      allow(contract).to receive(:cancel!).and_return(true)

      payment = double("Payment", contract: contract)

      # Stub ActiveRecord chain: where -> where -> includes -> find_each
      allow(Payment).to receive_message_chain(:where, :where, :includes, :find_each).and_yield(payment)

      # Admin lookup yields one admin
      allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)

      expect(Notification).to receive(:create!).with(
        user: admin,
        title: "Contratos liberados",
        message: "1 contratos han sido cancelados y liberados debido a falta de pago de reserva.",
        notification_type: "contracts_released"
      )

      # Run service
      service.call
    end

    it "does nothing (no notifications) when no payments to process" do
      # No payments yielded
      allow(Payment).to receive_message_chain(:where, :where, :includes, :find_each).and_return([])

      expect(Notification).not_to receive(:create!)

      service.call
    end

    it "logs when notification creation fails" do
      admin = double("User", id: 2)
      contract = double("Contract", id: 99, lot: double("Lot", name: "Lote X"))
      # ensure we stub the where.not chain used in the service
      allow(contract).to receive_message_chain(:payments, :where, :where, :not, :empty?).and_return(true)
      allow(contract).to receive(:may_reject?).and_return(false)
      allow(contract).to receive(:may_cancel?).and_return(true)
      allow(contract).to receive(:cancel!).and_return(true)

      payment = double("Payment", contract: contract)
      allow(Payment).to receive_message_chain(:where, :where, :includes, :find_each).and_yield(payment)

      allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)
      allow(Notification).to receive(:create!).and_raise(StandardError.new("boom"))

      expect(Rails.logger).to receive(:error).with(/Failed to create notification: boom/)

      service.call
    end
  end
end
