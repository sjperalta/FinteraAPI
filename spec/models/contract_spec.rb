require 'rails_helper'

RSpec.describe Contract, type: :model do
	# Minimal in‑memory objects (no DB writes) just to satisfy associations
	let(:project) do
		Project.new(
			name: 'TestProject', description: 'Desc', address: 'Addr',
			lot_count: 1, price_per_square_unit: 100, measurement_unit: 'm2', interest_rate: 5, guid: 'guid'
		)
	end

	let(:lot) do
		Lot.new(
			project: project,
			name: 'LotA',
			length: 10,
			width: 10,
			price: 10_000
		)
	end

	let(:user) do
		User.new(
			full_name: 'User One', phone: '99999999', identity: 'ID123', rtn: 'RTN123',
			email: 'user@example.com', password: 'Password1!', password_confirmation: 'Password1!'
		)
	end

	subject do
		described_class.new(
			lot: lot,
			applicant_user: user,
			payment_term: 12,
			financing_type: 'direct',
			reserve_amount: 1_000,
			down_payment: 2_000
		)
	end

	before do
		# Ensure AASM treats it as persisted (so it writes state) but we skip real DB work
		allow(subject).to receive(:persisted?).and_return(true)
		allow(subject).to receive(:save!).and_return(true)
		allow(subject).to receive(:update!).and_return(true)

		# Stub guards
		allow(subject).to receive(:valid_for_submission?).and_return(true)
		allow(subject).to receive(:can_be_approved?).and_return(true)

		# Stub side‑effects so we only test transitions
		allow(subject).to receive(:record_approval) do
			subject.approved_at = Time.current
			subject.active = true
		end
		allow(subject).to receive(:create_payments)
		allow(subject).to receive(:notify_approval)
		allow(subject).to receive(:notify_rejection)
		allow(subject).to receive(:release_lot)
		allow(subject).to receive(:delete_payments)
		allow(subject).to receive(:notify_cancellation)
	end

	describe 'AASM minimal transitions' do
		it 'starts pending' do
			expect(subject.aasm.current_state).to eq(:pending)
		end

		it 'submits when guard passes' do
			subject.submit
			expect(subject.aasm.current_state).to eq(:submitted)
		end

		it 'fails submit when guard false' do
			allow(subject).to receive(:valid_for_submission?).and_return(false)
			expect { subject.submit }.to raise_error(AASM::InvalidTransition)
			expect(subject.aasm.current_state).to eq(:pending)
		end

		it 'approves from submitted and runs callbacks' do
			subject.submit
			expect(subject).to receive(:record_approval)
			expect(subject).to receive(:create_payments)
			expect(subject).to receive(:notify_approval)
			subject.approve
			expect(subject.aasm.current_state).to eq(:approved)
			expect(subject.approved_at).not_to be_nil
			expect(subject.active).to be true
		end

		it 'rejects from submitted' do
			subject.submit
			expect(subject).to receive(:notify_rejection)
			subject.reject
			expect(subject.aasm.current_state).to eq(:rejected)
		end

		it 'cancels from rejected' do
			subject.submit
			subject.reject
			expect(subject).to receive(:release_lot)
			expect(subject).to receive(:delete_payments)
			expect(subject).to receive(:notify_cancellation)
			subject.cancel
			expect(subject.aasm.current_state).to eq(:cancelled)
		end
	end

	describe "#notify_approval" do
		it "creates a notification for applicant and admins" do
			user = double("User", id: 1)
			admin = double("User", id: 2)
			contract = described_class.new
			allow(contract).to receive(:applicant_user).and_return(user)
			allow(contract).to receive_message_chain(:lot, :name).and_return("Lote 1")
			allow(contract).to receive(:id).and_return(42)

			allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)

			expect(Notification).to receive(:create!).with(
				user: user,
				title: "Contrato Aprobado",
				message: "Tu contrato para Lote 1 ha sido aprobado",
				notification_type: "contract_approved"
			)

			expect(Notification).to receive(:create!).with(
				user: admin,
				title: "Contrato Aprobado",
				message: "Contrato #42 para Lote 1 ha sido aprobado.",
				notification_type: "contract_approved"
			)

			contract.send(:notify_approval)
		end
	end
end
