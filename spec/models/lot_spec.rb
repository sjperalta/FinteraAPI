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

  it 'sets the price before save using project price_per_square_unit' do
    # Avoid persisting by calling the callback directly
    allow(project).to receive(:price_for).and_call_original
    subject.send(:calculate_price)
    expect(subject.price).to be_present
  end
end
