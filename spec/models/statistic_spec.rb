require "rails_helper"

RSpec.describe Statistic, type: :model do
  describe "validations" do
    it "is valid with required numeric and date attributes" do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: 1000.0,
        total_interest: 50.0,
        payment_reserve: 100.0,
        payment_installments: 200.0,
        payment_down_payment: 300.0,
        new_customers: 5
      )

      expect(statistic).to be_valid
    end

    it "requires unique period_date" do
      date = Date.today
      described_class.create!(
        period_date: date,
        total_income: 0,
        total_interest: 0,
        payment_reserve: 0,
        payment_installments: 0,
        payment_down_payment: 0,
        new_customers: 0
      )

      duplicate = described_class.new(
        period_date: date,
        total_income: 0,
        total_interest: 0,
        payment_reserve: 0,
        payment_installments: 0,
        payment_down_payment: 0,
        new_customers: 0
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:period_date]).to include("has already been taken")
    end

    it "enforces non-negative numeric values" do
      statistic = described_class.new(
        period_date: Date.today,
        total_income: -1,
        total_interest: -1,
        payment_reserve: -1,
        payment_installments: -1,
        payment_down_payment: -1,
        new_customers: -1
      )

      expect(statistic).not_to be_valid
      %i[total_income total_interest payment_reserve payment_installments payment_down_payment].each do |attr|
        expect(statistic.errors[attr]).to include("must be greater than or equal to 0")
      end
      expect(statistic.errors[:new_customers]).to include("must be greater than or equal to 0")
    end
  end

  describe ".for_period" do
    it "returns statistics within the given range" do
      start_date = Date.today.beginning_of_month
      end_date = Date.today.end_of_month
      inside = described_class.create!(
        period_date: start_date + 5.days,
        total_income: 10,
        total_interest: 1,
        payment_reserve: 1,
        payment_installments: 2,
        payment_down_payment: 3,
        new_customers: 1
      )
      _outside = described_class.create!(
        period_date: start_date - 1.day,
        total_income: 10,
        total_interest: 1,
        payment_reserve: 1,
        payment_installments: 2,
        payment_down_payment: 3,
        new_customers: 1
      )

      result = described_class.for_period(start_date, end_date)
      expect(result).to include(inside)
      expect(result.count).to eq(1)
    end
  end

  describe ".total_payments_for_period" do
    it "sums payment components across the range using SQL expression" do
      start_date = Date.today.beginning_of_month
      end_date = Date.today.end_of_month

      described_class.create!(
        period_date: start_date + 1.day,
        total_income: 100,
        total_interest: 10,
        payment_reserve: 5,
        payment_installments: 15,
        payment_down_payment: 20,
        new_customers: 2
      )
      described_class.create!(
        period_date: start_date + 2.days,
        total_income: 200,
        total_interest: 20,
        payment_reserve: 10,
        payment_installments: 25,
        payment_down_payment: 30,
        new_customers: 3
      )

      # Expected sum: (5+15+20) + (10+25+30) = 105
      expect(described_class.total_payments_for_period(start_date, end_date)).to eq(105)
    end
  end
end
