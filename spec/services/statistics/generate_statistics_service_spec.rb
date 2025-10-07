# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Statistics::GenerateStatisticsService, type: :service do
  let(:period_date) { Date.new(2025, 9, 1) }
  let(:service) { described_class.new(period_date) }

  describe '#initialize' do
    it 'sets the period date' do
      expect(service.instance_variable_get(:@period_date)).to eq(period_date)
    end

    it 'parses string dates' do
      service_with_string = described_class.new('2025-09-01')
      expect(service_with_string.instance_variable_get(:@period_date)).to eq(period_date)
    end

    it 'defaults to today for invalid dates' do
      service_with_invalid = described_class.new('invalid')
      expect(service_with_invalid.instance_variable_get(:@period_date)).to eq(Date.today)
    end
  end

  describe '#call' do
    let!(:admin_user) do
      User.new(
        email: 'admin@example.com',
        password: 'password123',
        full_name: 'Admin User',
        phone: '0000000000',
        identity: '1234567890',
        rtn: '1234567890',
        role: 'admin',
        confirmed_at: Time.current
      ).tap(&:save!)
    end

    let!(:payment1) do
      Payment.new(
        amount: 1000.0,
        interest_amount: 50.0,
        payment_type: 'reservation',
        approved_at: period_date + 5.days,
        due_date: period_date + 10.days,
        status: 'paid',
        contract:
      ).tap(&:save!)
    end

    let!(:ledger_entry1) do
      ContractLedgerEntry.new(
        contract:,
        payment: payment1,
        amount: -1000.0, # Negative for payment
        description: "Proyecto #{project.name} - Reserva",
        entry_type: 'reservation',
        entry_date: period_date + 5.days
      ).tap(&:save!)
    end

    let!(:payment2) do
      Payment.new(
        amount: 2000.0,
        interest_amount: 100.0,
        payment_type: 'installment',
        approved_at: period_date + 25.days,
        due_date: period_date + 20.days,
        status: 'paid',
        contract:
      ).tap(&:save!)
    end

    let!(:ledger_entry2) do
      ContractLedgerEntry.new(
        contract:,
        payment: payment2,
        amount: -2000.0, # Negative for payment
        description: "Proyecto #{project.name} - Cuota 1",
        entry_type: 'installment',
        entry_date: period_date + 25.days
      ).tap(&:save!)
    end

    let!(:interest_ledger) do
      ContractLedgerEntry.new(
        contract:,
        amount: 150.0, # Positive for interest charged
        description: 'Intereses del mes',
        entry_type: 'interest',
        entry_date: period_date + 10.days
      ).tap(&:save!)
    end

    let!(:capital_repayment_ledger) do
      ContractLedgerEntry.new(
        contract:,
        amount: -500.0, # Negative for payment
        description: 'Abono a Capital',
        entry_type: 'prepayment',
        entry_date: period_date + 15.days
      ).tap(&:save!)
    end

    let!(:user) do
      User.new(
        email: 'user@example.com',
        password: 'password123',
        full_name: 'Test User',
        phone: '0000000000',
        identity: '2234567890',
        rtn: '2234567890',
        role: 'user',
        created_at: period_date + 1.day,
        confirmed_at: period_date + 1.day
      ).tap(&:save!)
    end

    let!(:contract) do
      Contract.new(
        applicant_user: user,
        creator: admin_user,
        lot:,
        payment_term: 12,
        financing_type: 'direct',
        reserve_amount: 1000.0,
        down_payment: 0.0,
        balance: 9000.0,
        currency: 'HNL',
        status: 'approved',
        created_at: period_date + 2.days
      ).tap(&:save!)
    end

    let!(:lot) do
      Lot.new(
        project:,
        name: 'Lot 1',
        address: '123 Test St',
        price: 10_000.0,
        length: 50,
        width: 40
      ).tap(&:save!)
    end

    let!(:project) do
      Project.new(
        name: 'Test Project',
        description: 'Test Description',
        address: '123 Test St',
        price_per_square_unit: 100.0,
        interest_rate: 1.5
      ).tap(&:save!)
    end

    it 'creates a statistic record with correct data' do
      expect { service.call }.to change(Statistic, :count).by(1)

      statistic = Statistic.find_by(period_date: period_date.beginning_of_month)
      expect(statistic).to be_present
      expect(statistic.total_income).to eq(3500.0) # 1000 + 2000 + 500 (payments only, interest separate)
      expect(statistic.total_interest).to eq(150.0) # Interest ledger entry
      expect(statistic.payment_reserve).to eq(1000.0)
      expect(statistic.payment_installments).to eq(2000.0)
      expect(statistic.payment_down_payment).to eq(0.0)
      expect(statistic.payment_capital_repayment).to eq(500.0) # New field
      expect(statistic.on_time_payment).to eq(1000.0) # payment1 was on time
      expect(statistic.delayed_payment).to eq(2000.0) # payment2 was delayed
      expect(statistic.new_customers).to eq(1)
      expect(statistic.new_contracts).to eq(1)
    end

    it 'updates existing statistic if it already exists' do
      existing_statistic = Statistic.create!(
        period_date: period_date.beginning_of_month,
        total_income: 0,
        total_interest: 0,
        payment_reserve: 0,
        payment_installments: 0,
        payment_down_payment: 0,
        payment_capital_repayment: 0,
        on_time_payment: 0,
        delayed_payment: 0,
        new_customers: 0,
        new_contracts: 0,
        total_income_growth: 0,
        total_interest_growth: 0,
        new_customers_growth: 0,
        new_contracts_growth: 0
      )

      expect { service.call }.not_to change(Statistic, :count)

      existing_statistic.reload
      expect(existing_statistic.total_income).to eq(3500.0)
    end

    it 'calculates growth when previous month exists' do
      previous_date = period_date.prev_month.beginning_of_month
      Statistic.create!(
        period_date: previous_date,
        total_income: 2000.0,
        total_interest: 100.0,
        payment_reserve: 500.0,
        payment_installments: 1000.0,
        payment_down_payment: 500.0,
        payment_capital_repayment: 0.0,
        on_time_payment: 1500.0,
        delayed_payment: 500.0,
        new_customers: 2,
        new_contracts: 2,
        total_income_growth: 0.0,
        total_interest_growth: 0.0,
        new_customers_growth: 0.0,
        new_contracts_growth: 0.0
      )

      service.call
      statistic = Statistic.find_by(period_date: period_date.beginning_of_month)

      expect(statistic.total_income_growth).to eq(75.0) # (3500-2000)/2000 * 100
      expect(statistic.total_interest_growth).to eq(50.0) # (150-100)/100 * 100
      expect(statistic.new_customers_growth).to eq(-50.0) # (1-2)/2 * 100
      expect(statistic.new_contracts_growth).to eq(-50.0) # (1-2)/2 * 100
    end

    it 'sets growth to 0 when no previous month exists' do
      service.call
      statistic = Statistic.find_by(period_date: period_date.beginning_of_month)

      expect(statistic.total_income_growth).to eq(0.0)
      expect(statistic.total_interest_growth).to eq(0.0)
      expect(statistic.new_customers_growth).to eq(0.0)
      expect(statistic.new_contracts_growth).to eq(0.0)
    end

    it 'creates notifications for admin users' do
      expect { service.call }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.user).to eq(admin_user)
      expect(notification.title).to eq('Actualizacion de estadisticas')
      expect(notification.notification_type).to eq('generate_statistics')
    end

    it 'handles errors gracefully' do
      allow(Statistic).to receive(:find_or_initialize_by).and_raise(StandardError.new('Database error'))
      expect(Rails.logger).to receive(:error).with('Error generating statistics: Database error')
      expect { service.call }.to raise_error(ActiveRecord::Rollback)
    end
  end

  describe 'performance optimization' do
    it 'uses single queries for data aggregation' do
      expect(ActiveRecord::Base.connection).to receive(:select_one).at_least(:once).and_call_original
      service.call
    end
  end
end
