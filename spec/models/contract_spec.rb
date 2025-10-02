# frozen_string_literal: true

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
      project:,
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
      lot:,
      applicant_user: user,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 1_000,
      down_payment: 2_000,
      amount: 10_000 # Add the amount field that was missing
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
    # Don't stub notify_approval to allow the actual ContractNotifier to be called
    # Don't stub notify_rejection to allow the actual ContractNotifier to be called
    allow(subject).to receive(:release_lot)
    allow(subject).to receive(:delete_payments)
    # Don't stub notify_cancellation to allow the actual ContractNotifier to be called

    # Mock ledger_entries association to return a mock that can sum amounts
    ledger_entries_mock = double('ledger_entries')
    allow(ledger_entries_mock).to receive(:total_balance).and_return(0) # Default balance
    allow(ledger_entries_mock).to receive(:create!).and_return(true)
    allow(subject).to receive(:ledger_entries).and_return(ledger_entries_mock)
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

      # Mock notification creation to avoid database calls
      allow(Notification).to receive(:create!)
      allow(User).to receive(:admins).and_return([])

      expect(Contracts::PaymentCreationService).to receive(:new).with(subject).and_call_original
      expect_any_instance_of(Contracts::PaymentCreationService).to receive(:call)
      expect(Contracts::ContractNotifier).to receive(:new).with(subject).and_call_original
      expect_any_instance_of(Contracts::ContractNotifier).to receive(:notify_approved).and_call_original

      subject.approve

      expect(subject.aasm.current_state).to eq(:approved)
      expect(subject.approved_at).not_to be_nil
      expect(subject.active).to be true
    end

    it 'rejects from submitted' do
      subject.submit

      # Mock the notification creation to avoid actual database calls
      allow(Notification).to receive(:create!)

      expect(Contracts::ContractNotifier).to receive(:new).with(subject).and_call_original
      expect_any_instance_of(Contracts::ContractNotifier).to receive(:notify_rejected).and_call_original

      subject.reject

      expect(subject.aasm.current_state).to eq(:rejected)
    end

    it 'cancels from rejected' do
      subject.submit

      # Mock the notification creation to avoid actual database calls
      allow(Notification).to receive(:create!)

      expect(Contracts::ContractNotifier).to receive(:new).with(subject).and_call_original
      expect_any_instance_of(Contracts::ContractNotifier).to receive(:notify_cancelled).and_call_original

      subject.cancel

      expect(subject.aasm.current_state).to eq(:cancelled)
    end
  end

  describe '#notify_approval' do
    it 'creates a notification for applicant and admins' do
      user = User.new(id: 1, email: 'user@example.com', password: 'password123', full_name: 'Test User',
                      phone: '1234567890', identity: '1234567890', rtn: '1234567890', role: 'user')
      seller = User.new(id: 1, email: 'seller@example.com', password: 'password123', full_name: 'Seller User',
                        phone: '1234567899', identity: '1234567899', rtn: '1234567899', role: 'seller')
      admin = User.new(id: 2, email: 'admin@example.com', password: 'password123', full_name: 'Admin User',
                       phone: '0987654321', identity: '0987654321', rtn: '0987654321', role: 'admin')

      # Stub password_digest to avoid Devise serialization issues
      allow(user).to receive(:password_digest).and_return('stubbed_digest')
      allow(admin).to receive(:password_digest).and_return('stubbed_digest')
      allow(seller).to receive(:password_digest).and_return('stubbed_digest')

      contract = described_class.new
      allow(contract).to receive(:applicant_user).and_return(user)
      allow(contract).to receive(:creator).and_return(seller)
      allow(contract).to receive_message_chain(:lot, :name).and_return('Lote 1')
      allow(contract).to receive(:id).and_return(42)

      allow(User).to receive(:admins).and_return([admin])

      expect(Notification).to receive(:create!).with(
        user:,
        title: 'Contrato Aprobado',
        message: 'Tu contrato para Lote 1 ha sido aprobado',
        notification_type: 'contract_approved'
      )

      expect(Notification).to receive(:create!).with(
        user: seller,
        title: 'Contrato Aprobado',
        message: 'Tu contrato para Lote 1 ha sido aprobado',
        notification_type: 'contract_approved'
      )

      expect(Notification).to receive(:create!).with(
        user: admin,
        title: 'Contrato Aprobado',
        message: 'Contrato #42 para Lote 1 ha sido aprobado.',
        notification_type: 'contract_approved'
      )

      contract.send(:notify_approval)
    end
  end

  describe 'cancel workflow' do
    it 'logs cancellation with current user' do
      user = double('User', email: 'admin@example.com')
      Thread.current[:current_user] = user

      # Mock notification creation to avoid database calls (needed for both reject and cancel)
      allow(Notification).to receive(:create!)

      subject.submit
      subject.reject

      expect(subject).to receive(:release_lot)
      expect(subject).to receive(:delete_payments)

      subject.cancel

      expect(subject.aasm.current_state).to eq(:cancelled)
      expect(subject.note).to include('Contrato cancelado')
      expect(subject.note).to include('por admin@example.com')
    ensure
      Thread.current[:current_user] = nil
    end

    it 'logs cancellation as system when no user' do
      # Mock notification creation to avoid database calls (needed for both reject and cancel)
      allow(Notification).to receive(:create!)

      subject.submit
      subject.reject

      expect(subject).to receive(:release_lot)
      expect(subject).to receive(:delete_payments)

      subject.cancel

      expect(subject.note).to include('por system')
    end

    it 'appends to existing notes' do
      subject.note = 'Existing note'
      user = double('User', email: 'admin@example.com')
      Thread.current[:current_user] = user

      # Mock notification creation to avoid database calls (needed for both reject and cancel)
      allow(Notification).to receive(:create!)

      subject.submit
      subject.reject
      subject.cancel

      expect(subject.note).to include('Existing note')
      expect(subject.note).to include('Contrato cancelado')
    ensure
      Thread.current[:current_user] = nil
    end
  end

  describe '#create_direct_payments' do
    let(:contract_date) { Date.new(2024, 1, 15) }

    before do
      allow(subject).to receive(:created_at).and_return(contract_date.to_time)
    end

    it 'creates payments with proper due dates' do
      # Mock project name access
      allow(subject).to receive_message_chain(:lot, :project, :name).and_return('TestProject')

      # Calculate expected values
      remaining_balance = subject.amount - subject.reserve_amount - subject.down_payment
      monthly_payment = remaining_balance / subject.payment_term

      # Expect PaymentCreationService to be called
      expect(Contracts::PaymentCreationService).to receive(:new).with(subject).and_call_original

      # Expect reservation payment (15 days after contract)
      expect(Payment).to receive(:create!).with(
        hash_including(
          contract: subject,
          description: 'Proyecto TestProject - Reserva',
          due_date: contract_date + 15.days, # January 30, 2024
          amount: subject.reserve_amount,
          status: 'pending',
          payment_type: 'reservation'
        )
      ).ordered.and_return(double(amount: subject.reserve_amount, description: 'Proyecto TestProject - Reserva'))

      # Expect down payment (1 month after reservation due date)
      reservation_due_date = contract_date + 15.days
      down_payment_due_date = reservation_due_date + 1.month
      expect(Payment).to receive(:create!).with(
        hash_including(
          contract: subject,
          description: 'Proyecto TestProject - Prima',
          due_date: down_payment_due_date, # reservation + 1 month (e.g. Feb 29, 2024)
          amount: subject.down_payment,
          status: 'pending',
          payment_type: 'down_payment'
        )
      ).ordered.and_return(double(amount: subject.down_payment, description: 'Proyecto TestProject - Prima'))

      # Expect installment payments (monthly after down payment)
      subject.payment_term.times do |i|
        installment_due_date = down_payment_due_date + (i + 1).months
        expect(Payment).to receive(:create!).with(
          hash_including(
            contract: subject,
            description: "Proyecto TestProject - Cuota #{i + 1}",
            due_date: installment_due_date,
            amount: monthly_payment,
            status: 'pending',
            payment_type: 'installment'
          )
        ).ordered.and_return(double(amount: monthly_payment, description: "Proyecto TestProject - Cuota #{i + 1}"))
      end

      Contracts::PaymentCreationService.new(subject).call
    end
  end

  describe 'payment schedule timing' do
    let(:contract_date) { Date.new(2024, 1, 15) }

    before do
      allow(subject).to receive(:created_at).and_return(contract_date.to_time)
      allow(subject).to receive_message_chain(:lot, :project, :name).and_return('TestProject')
    end

    it 'schedules reservation payment 15 days after contract creation' do
      expect(Payment).to receive(:create!).with(
        hash_including(
          due_date: Date.new(2024, 1, 30), # 15 days after January 15
          payment_type: 'reservation'
        )
      ).ordered

      # Allow other payments to be created
      allow(Payment).to receive(:create!).and_return(double(amount: 1000, description: 'test'))

      Contracts::PaymentCreationService.new(subject).send(:create_direct_payments)
    end

    it 'schedules down payment 1 month after contract creation' do
      # Allow reservation payment
      allow(Payment).to receive(:create!).and_return(double(amount: 1000, description: 'test'))

      # reservation is Jan 30, 2024 -> down payment is reservation + 1 month => Feb 29, 2024
      expect(Payment).to receive(:create!).with(
        hash_including(
          due_date: Date.new(2024, 2, 29),
          payment_type: 'down_payment'
        )
      ).ordered

      Contracts::PaymentCreationService.new(subject).send(:create_direct_payments)
    end

    it 'schedules first installment 1 month after down payment' do
      # Allow reservation and down payments
      allow(Payment).to receive(:create!).and_return(double(amount: 1000, description: 'test'))

      # down payment is Feb 29, 2024 -> first installment is down_payment + 1 month => Mar 29, 2024
      expect(Payment).to receive(:create!).with(
        hash_including(
          due_date: Date.new(2024, 3, 29),
          payment_type: 'installment',
          description: match(/Cuota 1/)
        )
      ).ordered

      Contracts::PaymentCreationService.new(subject).send(:create_direct_payments)
    end
  end

  describe '#balance' do
    it 'returns the total balance from ledger entries' do
      expect(subject.ledger_entries).to receive(:total_balance).and_return(5000)
      expect(subject.balance).to eq(5000)
    end
  end

  describe '#update_balance' do
    let(:lot) { Lot.new(name: 'Test Lot', price: 1000.0) }
    let(:user) { User.new(full_name: 'Test User', email: 'test@example.com') }
    let(:contract) do
      Contract.new(
        lot:,
        applicant_user: user,
        payment_term: 12,
        financing_type: 'direct',
        reserve_amount: 100.0,
        down_payment: 200.0,
        amount: 1000.0,
        status: 'pending'
      )
    end

    before do
      allow(contract).to receive(:may_close?).and_return(false)
      allow(contract).to receive(:balance).and_return(200.0)
    end

    context 'when amount_paid is nil' do
      it 'does not update balance and adds error' do
        contract.update_balance(nil)
        expect(contract.errors[:base]).to include('El monto pagado no puede ser nulo.')
      end
    end

    context 'when there is no pending balance' do
      it 'does not update balance and adds error' do
        allow(contract).to receive(:balance).and_return(0)
        contract.update_balance(100.0)
        expect(contract.errors[:base]).to include('El contrato no tiene balance pendiente.')
      end
    end

    context 'when amount_paid exceeds the balance' do
      it 'does not update balance and adds error' do
        allow(contract).to receive(:balance).and_return(50.0)
        contract.update_balance(100.0)
        expect(contract.errors[:base]).to include('El monto pagado excede el balance pendiente del contrato.')
      end
    end

    context 'when amount_paid is valid and does not settle the balance' do
      it 'creates a ledger entry and does not close the contract' do
        allow(contract).to receive(:close!) # Stub the close! method to make it a spy
        expect(contract.ledger_entries).to receive(:create!).with(amount: -100.0, description: 'Abono a Capital',
                                                                  entry_type: 'payment')
        contract.update_balance(100.0)
        expect(contract).not_to have_received(:close!)
      end
    end

    context 'when amount_paid settles the balance' do
      it 'creates a ledger entry and closes the contract' do
        allow(contract).to receive(:balance).and_return(100.0)
        allow(contract).to receive(:may_close?).and_return(true)
        expect(contract.ledger_entries).to receive(:create!).with(amount: -100.0, description: 'Abono a Capital',
                                                                  entry_type: 'payment')
        expect(contract).to receive(:close!)
        contract.update_balance(100.0)
      end
    end
  end
end
