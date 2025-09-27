# frozen_string_literal: true

require 'rails_helper'
require 'contract_ledger_entry'

# RSpec.describe Payment, type: :model do
RSpec.describe Payment, type: :model do
  let(:user) do
    User.new(
      full_name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
      phone: '123-456-7890',
      identity: '12345678901234',
      rtn: '12345678901234',
      role: 'user',
      confirmed_at: Time.current
    )
  end

  let(:project) do
    Project.new(
      name: 'Test Project',
      description: 'Test Description',
      address: 'Test Address',
      lot_count: 1,
      price_per_square_unit: 100.0,
      measurement_unit: 'm2',
      interest_rate: 5.0
    )
  end

  let(:lot) do
    Lot.new(
      project:,
      name: 'Test Lot',
      length: 10,
      width: 10,
      price: 1000.0
    )
  end

  let(:contract) do
    Contract.new(
      lot:,
      applicant_user: user,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 100.0,
      down_payment: 200.0,
      amount: 1000.0
    )
  end

  subject do
    described_class.new(
      amount: 100.0,
      due_date: Date.tomorrow,
      status: 'pending',
      payment_type: 'installment',
      contract:
    )
  end

  before do
    # This is a general setup to prevent tests from failing if a notification is unexpectedly created.
    # Specific notification tests will have more precise `expect` calls.
    allow(Notification).to receive(:create!)

    # Stub contract methods for non-scope tests
    allow(contract).to receive(:update_balance)
    allow(contract).to receive(:ledger_entries).and_return(double(create!: true))
    allow(contract).to receive(:balance).and_return(0)
    allow(contract).to receive(:may_close?).and_return(false)
  end

  describe 'constants' do
    it 'defines PAYMENT_TYPES' do
      expect(described_class::PAYMENT_TYPES).to eq(%w[reservation down_payment installment full advance])
    end

    it 'defines VALID_STATUSES' do
      expect(described_class::VALID_STATUSES).to eq(%w[pending submitted paid rejected])
    end
  end

  describe 'validations' do
    it 'requires payment_type to be valid' do
      subject.payment_type = 'invalid_type'
      expect(subject).not_to be_valid
      expect(subject.errors[:payment_type]).to include('is not included in the list')
    end

    it 'accepts valid payment types' do
      described_class::PAYMENT_TYPES.each do |type|
        subject.payment_type = type
        expect(subject).to be_valid, "Expected #{type} to be valid"
      end
    end

    it 'requires status to be valid' do
      subject.status = 'invalid_status'
      expect(subject).not_to be_valid
      expect(subject.errors[:status]).to include('is not included in the list')
    end

    it 'accepts valid statuses' do
      described_class::VALID_STATUSES.each do |status|
        subject.status = status
        expect(subject).to be_valid, "Expected #{status} to be valid"
      end
    end

    it 'requires amount to be greater than 0' do
      subject.amount = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to include('must be greater than 0')

      subject.amount = -10
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to include('must be greater than 0')
    end

    it 'allows nil interest_amount' do
      subject.interest_amount = nil
      expect(subject).to be_valid
    end

    it 'requires interest_amount to be non-negative when present' do
      subject.interest_amount = -5
      expect(subject).not_to be_valid
      expect(subject.errors[:interest_amount]).to include('must be greater than or equal to 0')

      subject.interest_amount = 0
      expect(subject).to be_valid

      subject.interest_amount = 10
      expect(subject).to be_valid
    end
  end

  describe 'notification methods' do
    before do
      allow(subject).to receive(:id).and_return(123)
      allow(subject).to receive(:description).and_return('Test Payment')
      allow(subject).to receive(:paid_amount).and_return(100.0)
    end

    describe '#notify_submission' do
      it 'creates submission notification' do
        expect(Notification).to receive(:create!).with(
          user:,
          title: 'Actualización Pago',
          message: 'Pago #123 a sido enviado para aprobación.',
          notification_type: 'payment_submitted'
        )

        subject.send(:notify_submission)
      end
    end

    describe '#notify_approval' do
      it 'creates approval notification for user and admins' do
        admin_relation = double('AdminRelation')
        allow(admin_relation).to receive(:find_each)
        allow(User).to receive(:where).with(role: 'admin').and_return(admin_relation)

        expect(Notification).to receive(:create!).once

        subject.send(:notify_approval)
      end
    end

    describe '#notify_rejection' do
      it 'creates rejection notification' do
        expect(Notification).to receive(:create!).with(
          user:,
          title: 'Actualización Pago',
          message: 'Pago #123 ha sido rechazado.',
          notification_type: 'payment_rejected'
        )

        subject.send(:notify_rejection)
      end
    end

    describe '#notify_overdue_interest' do
      it 'creates overdue interest notification' do
        overdue_interest = 25.50

        expect(Notification).to receive(:create!).with(
          user:,
          title: 'Pago Atrasado: Test Payment',
          message: 'Se ha generado un cargo por mora de 25.5.',
          notification_type: 'payment_overdue'
        )

        subject.notify_overdue_interest(overdue_interest)
      end
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
        expect { subject.submit }.not_to raise_error
        expect(subject.aasm.current_state).to eq(:submitted)
      end
    end

    context 'approve' do
      before do
        allow(subject).to receive(:document_attached?).and_return(true)
        subject.submit
        allow(subject).to receive(:description).and_return('Test Payment')
      end

      context 'when payment amount is invalid' do
        it 'does not approve and adds error' do
          subject.amount = nil
          allow(contract).to receive(:balance).and_return(200.0) # Ensure balance is sufficient
          expect { subject.approve }.to raise_error(AASM::InvalidTransition)
          expect(subject.errors[:base]).to include('Monto pagado no especificado.')
        end
      end

      context 'when contract has no pending balance' do
        it 'does not approve and adds error' do
          allow(contract).to receive(:balance).and_return(0) # Simulate no pending balance
          expect { subject.approve }.to raise_error(AASM::InvalidTransition)
          expect(subject.errors[:base]).to include('El contrato no tiene balance pendiente.')
        end
      end

      context 'when payment exceeds balance' do
        it 'does not approve and adds error' do
          allow(contract).to receive(:balance).and_return(50.0) # Simulate insufficient balance
          subject.amount = 100.0
          expect { subject.approve }.to raise_error(AASM::InvalidTransition)
          expect(subject.errors[:base]).to include("El monto pagado de '100.0' excede el balance pendiente del contrato.")
        end
      end

      context 'when all validations pass' do
        it 'approves the payment' do
          allow(contract).to receive(:balance).and_return(200.0) # Ensure balance is sufficient
          expect(subject).to receive(:record_approval_timestamp)
          expect(contract.ledger_entries).to receive(:create!).with(
            amount: -100.0,
            description: 'Pago por Test Payment',
            entry_type: 'payment',
            payment: subject
          )
          allow(contract).to receive(:may_close?).and_return(false)
          subject.approve
          expect(subject.aasm.current_state).to eq(:paid)
        end
      end

      context 'when payment settles the balance' do
        it 'closes the contract' do
          allow(contract).to receive(:balance).and_return(100.0)
          subject.amount = 100.0
          # exact guard behavior should be exercised rather than stubbing
          expect(subject).to receive(:record_approval_timestamp)
          expect(contract.ledger_entries).to receive(:create!).with(
            amount: -100.0,
            description: 'Pago por Test Payment',
            entry_type: 'payment',
            payment: subject
          )
          allow(contract).to receive(:may_close?).and_return(true)
          expect(contract).to receive(:close!)
          allow(User).to receive(:admins).and_return([])

          subject.approve

          expect(subject.aasm.current_state).to eq(:paid)
        end
      end
    end

    context 'undo' do
      before do
        allow(subject).to receive(:document_attached?).and_return(true)
        # make contract have sufficient balance so approval can proceed
        allow(contract).to receive(:balance).and_return(200.0)
        allow(contract).to receive(:may_close?).and_return(false)
        allow(User).to receive(:admins).and_return([])
        # avoid persisting in setup; stub the timestamp recorder
        allow(subject).to receive(:record_approval_timestamp)

        subject.submit
        subject.approve
      end
    end

    context 'reject' do
      before do
        allow(subject).to receive(:document_attached?).and_return(true)
        subject.submit
      end

      it 'transitions from submitted to rejected' do
        expect(subject).to receive(:notify_rejection)

        subject.reject
        expect(subject.aasm.current_state).to eq(:rejected)
      end
    end
  end

  describe 'scopes' do
    let!(:user_record) do
      User.create!(full_name: 'Test User', email: 'test@example.com', password: 'password123',
                   confirmed_at: Time.current, phone: '1234567890', identity: '123456789', rtn: '123456789', role: 'user')
    end
    let!(:project_record) do
      Project.create!(name: 'Test Project', description: 'Test Description', address: 'Test Address', lot_count: 1,
                      price_per_square_unit: 100.0, measurement_unit: 'm2', interest_rate: 5.0)
    end
    let!(:lot_record) { Lot.create!(project: project_record, name: 'Test Lot', length: 10, width: 10, price: 1000.0) }

    let!(:contract_record) do
      # Create a real contract for the scope tests
      Contract.create!(
        lot: lot_record,
        applicant_user: user_record,
        payment_term: 12,
        financing_type: 'direct',
        reserve_amount: 100.0,
        down_payment: 200.0,
        amount: 1000.0
      )
    end

    let!(:pending_payment) do
      described_class.create!(
        amount: 100.0,
        due_date: Date.tomorrow,
        status: 'pending',
        payment_type: 'installment',
        contract: contract_record
      )
    end

    let!(:submitted_payment) do
      described_class.create!(
        amount: 200.0,
        due_date: Date.tomorrow,
        status: 'submitted',
        payment_type: 'installment',
        contract: contract_record
      )
    end

    let!(:overdue_payment) do
      described_class.create!(
        amount: 150.0,
        due_date: 1.day.ago,
        status: 'pending',
        payment_type: 'installment',
        contract: contract_record
      )
    end

    let!(:future_payment) do
      described_class.create!(
        amount: 250.0,
        due_date: 1.day.from_now,
        status: 'pending',
        payment_type: 'installment',
        contract: contract_record
      )
    end

    describe '.pending' do
      it 'returns payments with pending status' do
        expect(described_class.pending).to include(pending_payment)
        expect(described_class.pending).not_to include(submitted_payment)
      end
    end

    describe '.overdue' do
      it 'returns overdue pending payments ordered by due date' do
        overdue_payments = described_class.overdue

        expect(overdue_payments).to include(overdue_payment)
        expect(overdue_payments).not_to include(future_payment)
        expect(overdue_payments).not_to include(submitted_payment)
      end
    end
  end
end
