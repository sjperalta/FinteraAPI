require 'rails_helper'

RSpec.describe Lot, type: :model do
  let(:project) { Project.new(name: 'P', description: 'D', address: 'A', price_per_square_unit: 100.0, measurement_unit: 'm2', interest_rate: 1.0, commission_rate: 5.0) }
  subject { described_class.new(name: 'Lote A', length: 10.0, width: 5.0, project: project) }

  it 'is valid with required attributes' do
    expect(subject).to be_valid
  end

  it 'calculates area in m2 and converts based on project measurement_unit' do
    # default project unit m2
    expect(subject.area_m2).to eq(50.0)
    expect(subject.area_in_project_unit).to be_within(0.0001).of(50.0)

    project.measurement_unit = 'ft2'
    expect(subject.area_in_project_unit).to be_within(0.0001).of(50.0 * 10.7639)

    project.measurement_unit = 'vara2'
    expect(subject.area_in_project_unit).to be_within(0.0001).of(50.0 * 1.431)
  end

  it 'calculates price using formula length * width * project.price_per_square_unit when no override' do
    subject.send(:calculate_price)
    expected = subject.length.to_d * subject.width.to_d * project.price_per_square_unit.to_d
    expect(subject.price.to_d).to eq(expected)
  end

  it 'uses override_price when present' do
    subject.override_price = 9999.99
    subject.send(:calculate_price)
    expect(subject.price.to_d).to eq(9999.99.to_d)
  end

  it 'recalculates formula after clearing override_price' do
    subject.override_price = 5000
    subject.send(:calculate_price)
    expect(subject.price.to_d).to eq(5000.to_d)
    subject.override_price = nil
    subject.send(:calculate_price)
    expected = subject.length.to_d * subject.width.to_d * project.price_per_square_unit.to_d
    expect(subject.price.to_d).to eq(expected)
  end
end
