# frozen_string_literal: true

require 'rails_helper'

# Test suite for the CapitalRepaymentService
RSpec.describe Contracts::CapitalRepaymentService, type: :service do
  describe '#call' do
    let(:user) do
      User.new(
        full_name: 'Test User',
        phone: '555-0000',
        identity: 'ID123',
        rtn: 'RTN123',
        email: 'user@example.com',
        role: User::ROLE_USER,
        password: 'password123',
        password_confirmation: 'password123'
      ).tap do |u|
        u.skip_confirmation!
        u.save!
      end
    end

    let(:project) do
      Project.new(
        name: 'Test Project',
        description: 'A test project',
        address: '123 Test St',
        price_per_square_unit: 100,
        interest_rate: 5,
        commission_rate: 10,
        measurement_unit: 'm2'
      ).tap(&:save!)
    end

    let(:lot) do
      Lot.new(
        project:,
        name: 'Lot 1',
        address: '123 Test St',
        length: 10,
        width: 10,
        status: 'available'
      ).tap(&:save!)
    end

    let(:contract) do
      Contract.new(
        lot:,
        applicant_user: user,
        creator: user,
        payment_term: 12,
        financing_type: 'direct',
        reserve_amount: 1000,
        down_payment: 2000,
        status: 'approved',
        approved_at: Time.current,
        active: true
      ).tap(&:save!)
    end

    before do
      # Create payments for the contract
      # Let's create 5 payments of 5000 each
      5.times do |i|
        Payment.create!(
          contract:,
          amount: 5000,
          due_date: Date.current + (i + 1).months,
          payment_type: 'installment',
          description: "Payment #{i + 1}",
          status: 'pending'
        )
      end

      # Set the contract amount to match the payments we're creating
      # The lot has area 10x10 = 100 units at $100/unit = $10,000
      # But we need a higher amount to accommodate the payments
      contract.update!(amount: 50_000)

      # Create an initial ledger entry to establish the contract balance
      # Use 'down_payment' as a valid entry_type
      contract.ledger_entries.create!(
        amount: 25_000,
        description: 'Initial contract balance',
        entry_type: 'down_payment'
      )
    end

    context 'when repayment amount is valid' do
      it 'applies prepayment and marks correct payments as readjustment' do
        # Initial balance: 25,000
        # User makes a capital repayment of 11,000
        # After prepayment, remaining balance: 14,000
        # The service should mark the last payments that cover this remaining balance
        # Last 3 payments (3 x 5,000 = 15,000) cover the 14,000 remaining
        service = described_class.new(
          contract:,
          amount: 11_000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:message]).to eq('Amortización de capital registrada exitosamente')
        expect(result[:reajusted_payments_count]).to eq(3)

        # Verify the last 3 payments are marked as readjustment
        readjusted = contract.payments.where(status: 'readjustment').order(due_date: :desc)
        expect(readjusted.count).to eq(3)
      end

      it 'reduces the contract balance' do
        initial_balance = contract.balance
        service = described_class.new(
          contract:,
          amount: 11_000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be true
        expect(contract.reload.balance).to eq(initial_balance - 11_000)
      end

      it 'triggers credit score update' do
        service = described_class.new(
          contract:,
          amount: 5000,
          current_user: user
        )

        expect(UpdateCreditScoresJob).to receive(:perform_later).with(user.id)

        service.call
      end

      it 'marks payments based on remaining balance, not repayment amount' do
        # Initial balance: 25,000
        # User makes a capital repayment of 20,000
        # After prepayment, remaining balance: 5,000
        # Only the LAST payment (5,000) should be marked for readjustment
        # NOT the 4 payments that would cover the 20,000 repayment amount
        service = described_class.new(
          contract:,
          amount: 20_000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be true
        expect(result[:reajusted_payments_count]).to eq(1)

        # Verify only the last payment is marked as readjustment
        readjusted = contract.payments.where(status: 'readjustment')
        expect(readjusted.count).to eq(1)
        expect(readjusted.first.description).to eq('Payment 5')
      end
    end

    context 'when repayment amount is invalid' do
      it 'returns error for zero amount' do
        service = described_class.new(
          contract:,
          amount: 0,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include('El monto de amortización debe ser mayor a cero')
      end

      it 'returns error for negative amount' do
        service = described_class.new(
          contract:,
          amount: -1000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include('El monto de amortización debe ser mayor a cero')
      end

      it 'returns error when amount exceeds balance' do
        service = described_class.new(
          contract:,
          amount: 50_000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('excede el balance pendiente')
      end
    end

    context 'when there are no pending payments' do
      before do
        # Mark all payments as paid
        contract.payments.update_all(status: 'paid')
      end

      it 'still applies the prepayment but marks no payments' do
        service = described_class.new(
          contract:,
          amount: 5000,
          current_user: user
        )

        result = service.call

        expect(result[:success]).to be true
        expect(result[:reajusted_payments_count]).to eq(0)
      end
    end
  end
end
