require "rails_helper"

RSpec.describe Payment, type: :model do
  let(:user) { double("User", id: 1, full_name: "Test User") }
  let(:contract) { double("Contract", applicant_user: user, update_balance: true, marked_for_destruction?: false) }

  subject do
    payment = described_class.new(
      amount: 100.0,
      due_date: Date.tomorrow,
      status: "pending",
      payment_type: "installment"
    )
    # Stub the contract association to return the double, avoiding the mismatch error.
    allow(payment).to receive(:contract).and_return(contract)
    payment
  end

  before do
    # This is a general setup to prevent tests from failing if a notification is unexpectedly created.
    # Specific notification tests will have more precise `expect` calls.
    allow(Notification).to receive(:create!)
  end

  describe "validations" do
    it "requires payment_type to be valid" do
      subject.payment_type = "invalid_type"
      expect(subject).not_to be_valid
      expect(subject.errors[:payment_type]).to include("is not included in the list")
    end

    it "accepts valid payment types" do
      Payment::PAYMENT_TYPES.each do |type|
        subject.payment_type = type
        expect(subject).to be_valid, "Expected #{type} to be valid"
      end
    end

    it "requires status to be valid" do
      subject.status = "invalid_status"
      expect(subject).not_to be_valid
      expect(subject.errors[:status]).to include("is not included in the list")
    end

    it "requires amount to be greater than 0" do
      subject.amount = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to include("must be greater than 0")

      subject.amount = -10
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to include("must be greater than 0")
    end

    it "allows nil interest_amount" do
      subject.interest_amount = nil
      expect(subject).to be_valid
    end

    it "requires interest_amount to be non-negative when present" do
      subject.interest_amount = -5
      expect(subject).not_to be_valid
      expect(subject.errors[:interest_amount]).to include("must be greater than or equal to 0")

      subject.interest_amount = 0
      expect(subject).to be_valid

      subject.interest_amount = 10
      expect(subject).to be_valid
    end
  end

  describe "notification methods" do
    before do
      allow(subject).to receive(:id).and_return(123)
      allow(subject).to receive(:description).and_return("Test Payment")
      allow(subject).to receive(:paid_amount).and_return(100.0)
    end

    describe "#notify_submission" do
      it "creates submission notification" do
        expect(Notification).to receive(:create!).with(
          user: user,
          title: "Actualización Pago",
          message: "Pago #123 a sido enviado para aprobación.",
          notification_type: "payment_submitted"
        )

        subject.send(:notify_submission)
      end
    end

    describe "#notify_rejection" do
      it "creates rejection notification" do
        expect(Notification).to receive(:create!).with(
          user: user,
          title: "Actualización Pago",
          message: "Pago #123 ha sido rechazado.",
          notification_type: "payment_rejected"
        )

        subject.send(:notify_rejection)
      end
    end
  end

  describe "state machine transitions" do
    context "submit" do
      it "does not submit if no document attached" do
        allow(subject).to receive(:document_attached?).and_return(false)
        expect { subject.submit }.to raise_error(AASM::InvalidTransition)
      end

      it "submits when document attached" do
        allow(subject).to receive(:document_attached?).and_return(true)
        expect { subject.submit }.not_to raise_error
        expect(subject.aasm.current_state).to eq(:submitted)
      end
    end

    context "approve" do
      before do
        allow(subject).to receive(:document_attached?).and_return(true)
        subject.submit
      end

      it "approves when can_be_approved? is true" do
        allow(subject).to receive(:can_be_approved?).and_return(true)
        expect(subject).to receive(:record_approval_timestamp)
        allow(subject).to receive(:update_contract_balance)
        allow(User).to receive_message_chain(:where, :find_each)

        subject.approve
        expect(subject.aasm.current_state).to eq(:paid)
      end
    end
  end
end
