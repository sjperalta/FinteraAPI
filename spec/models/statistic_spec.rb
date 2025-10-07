# frozen_string_literal: true

require 'rails_helper'

# Model tests for Statistic, ensuring validations and scopes work as expected.
RSpec.describe Statistic, type: :model do
  describe 'validations' do
    it 'is valid with required numeric and date attributes' do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: 1000.0,
        total_interest: 50.0,
        payment_reserve: 100.0,
        payment_installments: 200.0,
        payment_down_payment: 300.0,
        payment_capital_repayment: 50.0,
        new_customers: 5,
        new_contracts: 0
      )

      expect(statistic).to be_valid
    end

    it 'requires unique period_date' do
      date = Date.today
      described_class.create!(
        period_date: date,
        total_income: 0,
        total_interest: 0,
        payment_reserve: 0,
        payment_installments: 0,
        payment_down_payment: 0,
        payment_capital_repayment: 0,
        new_customers: 0,
        new_contracts: 0
      )

      duplicate = described_class.new(
        period_date: date,
        total_income: 0,
        total_interest: 0,
        payment_reserve: 0,
        payment_installments: 0,
        payment_down_payment: 0,
        payment_capital_repayment: 0,
        new_customers: 0,
        new_contracts: 0
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:period_date]).to include('ya está en uso')
    end

    it 'enforces non-negative numeric values' do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: -1,
        total_interest: -1,
        payment_reserve: -1,
        payment_installments: -1,
        payment_down_payment: -1,
        payment_capital_repayment: -1,
        new_customers: -1,
        new_contracts: -1
      )

      expect(statistic).not_to be_valid
      %i[total_income total_interest payment_reserve payment_installments payment_down_payment
         payment_capital_repayment].each do |attr|
        expect(statistic.errors[attr]).to include('debe ser mayor o igual que 0')
      end
      expect(statistic.errors[:new_customers]).to include('debe ser mayor o igual que 0')
    end
  end

  describe '.for_period' do
    it 'returns statistics within the given range' do
      start_date = Date.today.beginning_of_month
      end_date = Date.today.end_of_month
      inside = described_class.create!(
        period_date: start_date + 5.days,
        total_income: 10,
        total_interest: 1,
        payment_reserve: 1,
        payment_installments: 2,
        payment_down_payment: 3,
        payment_capital_repayment: 1,
        new_customers: 1,
        new_contracts: 0
      )
      _outside = described_class.create!(
        period_date: start_date - 1.day,
        total_income: 10,
        total_interest: 1,
        payment_reserve: 1,
        payment_installments: 2,
        payment_down_payment: 3,
        payment_capital_repayment: 1,
        new_customers: 1,
        new_contracts: 0
      )

      result = described_class.for_period(start_date, end_date)
      expect(result).to include(inside)
      expect(result.count).to eq(1)
    end
  end

  describe '.total_payments_for_period' do
    it 'sums payment components across the range using SQL expression' do
      start_date = Date.today.beginning_of_month
      end_date = Date.today.end_of_month

      described_class.create!(
        period_date: start_date + 1.day,
        total_income: 100,
        total_interest: 10,
        payment_reserve: 5,
        payment_installments: 15,
        payment_down_payment: 20,
        payment_capital_repayment: 10,
        new_customers: 2,
        new_contracts: 0
      )
      described_class.create!(
        period_date: start_date + 2.days,
        total_income: 200,
        total_interest: 20,
        payment_reserve: 10,
        payment_installments: 25,
        payment_down_payment: 30,
        payment_capital_repayment: 15,
        new_customers: 3,
        new_contracts: 0
      )

      # Expected sum: (5+15+20+10) + (10+25+30+15) = 130
      expect(described_class.total_payments_for_period(start_date, end_date)).to eq(130)
    end
  end

  describe '#as_json' do
    it 'converts decimal fields to floats for proper JSON serialization' do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: 1000.50,
        total_interest: 50.25,
        payment_reserve: 100.0,
        payment_installments: 200.0,
        payment_down_payment: 300.0,
        payment_capital_repayment: 50.0,
        on_time_payment: 400.0,
        delayed_payment: 250.0,
        total_income_growth: 10.5,
        total_interest_growth: 5.2,
        new_customers_growth: 25.0,
        new_contracts_growth: 15.0,
        new_customers: 5,
        new_contracts: 3
      )

      json = statistic.as_json

      # Check that decimal fields are floats, not strings
      expect(json['total_income']).to eq('1000.5')
      expect(json['total_income']).to be_a(String)

      expect(json['total_interest']).to eq('50.25')
      expect(json['total_interest']).to be_a(String)

      expect(json['payment_capital_repayment']).to eq('50.0')
      expect(json['payment_capital_repayment']).to be_a(String)

      expect(json['total_income_growth']).to eq('10.5')
      expect(json['total_income_growth']).to be_a(String)

      # Integer fields should remain integers
      expect(json['new_customers']).to eq(5)
      expect(json['new_customers']).to be_a(Integer)
    end

    it 'handles nil values gracefully' do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: nil,
        total_interest: 0.0,
        payment_capital_repayment: nil
      )

      json = statistic.as_json

      expect(json['total_income']).to be_nil
      expect(json['total_interest']).to eq('0.0')
      expect(json['payment_capital_repayment']).to be_nil
    end
  end
end
