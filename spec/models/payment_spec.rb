require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:user) { User.new(full_name: 'Test', phone: '555', identity: 'ID1', rtn: 'RTN1', email: 'u@example.com', role: 'user', password: 'pass1', password_confirmation: 'pass1') }
  let(:contract) { Contract.new(applicant_user: user) }
  subject { described_class.new(amount: 100.0, due_date: Date.tomorrow, status: 'pending', contract: contract) }

  it 'is valid with required attributes' do
    expect(subject).to be_valid
  end

  describe 'scopes' do
    it 'defines pending and overdue scopes' do
      expect(Payment).to respond_to(:pending)
      expect(Payment).to respond_to(:overdue)
    end
  end

  describe 'state machine transitions' do
    context 'submit' do
      it 'does not submit if no document attached' do
        allow(subject).to receive(:document_attached?).and_return(false)
        expect { subject.submit }.to raise_error(AASM::InvalidTransition)
      end

      it 'submits when document attached' do
        allow(subject).to receive(:document_attached?).and_return(true)
        allow(subject).to receive(:notify_submission)
        expect { subject.submit }.not_to raise_error
        expect(subject.aasm.current_state).to eq(:submitted)
      end
    end

    context 'approve' do
      before do
        allow(subject).to receive(:document_attached?).and_return(true)
        allow(subject).to receive(:notify_submission)
        subject.submit
      end

      it 'approves when can_be_approved? is true' do
        allow(subject).to receive(:can_be_approved?).and_return(true)
        expect(subject).to receive(:record_approval_timestamp)
        allow(subject).to receive(:update_contract_balance)
        allow(subject).to receive(:notify_approval)
        subject.approve
        expect(subject.aasm.current_state).to eq(:paid)
      end
    end
  end

end
