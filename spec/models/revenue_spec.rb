require 'rails_helper'

RSpec.describe Revenue, type: :model do
  describe 'validations (minimal)' do
    it 'is valid with required attributes' do
      rev = described_class.new(payment_type: 'reservation', year: 2024, month: 5, amount: 10.50)
      expect(rev).to be_valid
    end

    it 'is invalid with wrong payment_type' do
      rev = described_class.new(payment_type: 'other', year: 2024, month: 5, amount: 1)
      expect(rev).not_to be_valid
      expect(rev.errors[:payment_type]).not_to be_empty
    end
  end

  describe '.total_revenue_for_year' do
    it 'queries grouped sum for the given year using chained relation methods' do
      year = 2024
      relation = double('Relation')
      grouped = double('GroupedRelation')
      result_hash = { 'reservation' => 100.0, 'installment' => 250.0 }

      expect(described_class).to receive(:where).with(year: year).and_return(relation)
      expect(relation).to receive(:group).with(:payment_type).and_return(grouped)
      expect(grouped).to receive(:sum).with(:amount).and_return(result_hash)

      expect(described_class.total_revenue_for_year(year)).to eq(result_hash)
    end
  end

  describe '.monthly_revenue_for_year_and_type' do
    it 'returns ordered plucked amounts via relation chain' do
      year = 2024
      type = 'reservation'
      relation = double('Relation')
      ordered = double('OrderedRelation')
      amounts = [10.0, 15.5, 20.25]

      expect(described_class).to receive(:where).with(year: year, payment_type: type).and_return(relation)
      expect(relation).to receive(:order).with(:month).and_return(ordered)
      expect(ordered).to receive(:pluck).with(:amount).and_return(amounts)

      expect(described_class.monthly_revenue_for_year_and_type(year, type)).to eq(amounts)
    end
  end

  describe '#formatted_amount' do
    it 'formats amount to two decimals with dollar sign' do
      rev = described_class.new(amount: 123.456)
      expect(rev.formatted_amount).to eq('$123.46')
    end
  end
end
