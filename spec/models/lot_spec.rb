require 'rails_helper'

RSpec.describe Lot, type: :model do
  let(:project) { Project.new(name: 'P', description: 'D', address: 'A', price_per_square_vara: 100.0, interest_rate: 1.0, commission_rate: 5.0) }
  subject { described_class.new(name: 'Lote A', length: 10.0, width: 5.0, project: project) }

  it 'is valid with required attributes' do
    expect(subject).to be_valid
  end

  it 'calculates area in m2 and other units' do
    expect(subject.area_m2).to eq(50.0)
    expect(subject.area_square_feet).to be_within(0.001).of(50.0 * 10.7639)
    expect(subject.area_square_vara).to be_within(0.001).of(50.0 * 1.431)
  end

  it 'sets the price before save using project price_per_square_vara' do
    # Avoid persisting by calling the callback directly
    allow(project).to receive(:price_per_square_vara).and_return(100.0)
    subject.send(:calculate_price)
    expect(subject.price).to be_present
  end
end
