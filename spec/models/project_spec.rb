# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'validations' do
    it 'validates presence of name, description, and address' do
      project = described_class.new
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
      expect(project.errors[:description]).to include("can't be blank")
      expect(project.errors[:address]).to include("can't be blank")
    end

    it 'validates numericality of price_per_square_unit and interest_rate greater than 0' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 0,
        interest_rate: 0,
        commission_rate: 5.0,
        measurement_unit: 'm2'
      )
      expect(project).not_to be_valid
      expect(project.errors[:price_per_square_unit]).to include('must be greater than 0')
      expect(project.errors[:interest_rate]).to include('must be greater than 0')
    end

    it 'validates commission_rate between 0 and 100' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        interest_rate: 5.0,
        commission_rate: 101,
        measurement_unit: 'm2'
      )
      expect(project).not_to be_valid
      expect(project.errors[:commission_rate]).to include('must be less than or equal to 100')

      project.commission_rate = -1
      expect(project).not_to be_valid
      expect(project.errors[:commission_rate]).to include('must be greater than or equal to 0')
    end

    it 'validates interest_rate between 0 and 100' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        interest_rate: 101,
        commission_rate: 5.0,
        measurement_unit: 'm2'
      )
      expect(project).not_to be_valid
      expect(project.errors[:interest_rate]).to include('must be less than or equal to 100')

      project.interest_rate = -1
      expect(project).not_to be_valid
      expect(project.errors[:interest_rate]).to include('must be greater than or equal to 0')
    end

    it 'validates measurement_unit inclusion' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        interest_rate: 5.0,
        commission_rate: 5.0,
        measurement_unit: 'invalid_unit'
      )
      expect(project).not_to be_valid
      expect(project.errors[:measurement_unit]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    let!(:project1) do
      described_class.create!(name: 'P1', description: 'D1', address: 'A1', price_per_square_unit: 100.0,
                              measurement_unit: 'm2', interest_rate: 5.0, commission_rate: 5.0)
    end
    let!(:project2) do
      described_class.create!(name: 'P2', description: 'D2', address: 'A2', price_per_square_unit: 200.0,
                              measurement_unit: 'ft2', interest_rate: 10.0, commission_rate: 10.0)
    end

    it 'filters by project_type' do
      project1.update!(project_type: 'residential')
      project2.update!(project_type: 'commercial')
      expect(described_class.by_project_type('residential')).to contain_exactly(project1)
    end

    it 'filters by price_range' do
      expect(described_class.by_price_range(150, 250)).to contain_exactly(project2)
    end

    it 'filters by interest_rate' do
      expect(described_class.by_interest_rate(10.0)).to contain_exactly(project2)
    end
  end

  describe 'callbacks' do
    it 'generates a guid before create' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        measurement_unit: 'm2',
        interest_rate: 5.0,
        commission_rate: 5.0
      )
      expect(SecureRandom).to receive(:uuid).and_return('test-guid')
      project.save!
      expect(project.guid).to eq('test-guid')
    end

    it 'initializes lot_count to 0 before create' do
      project = described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        measurement_unit: 'm2',
        interest_rate: 5.0,
        commission_rate: 5.0
      )
      project.save!
      expect(project.lot_count).to eq(0)
    end

    it 'updates lot_count after save' do
      project = described_class.create!(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        measurement_unit: 'm2',
        interest_rate: 5.0,
        commission_rate: 5.0
      )

      # create real lots so counter_cache updates
      project.lots.create!(name: 'L1', length: 10.0, width: 10.0, price: 100.0, measurement_unit: 'm2',
                           status: 'available')
      project.lots.create!(name: 'L2', length: 20.0, width: 5.0, price: 100.0, measurement_unit: 'm2',
                           status: 'available')

      project.reload
      expect(project.lot_count).to eq(2)
    end
  end

  describe '#price_for' do
    let(:project) do
      described_class.new(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        measurement_unit: 'm2',
        interest_rate: 5.0,
        commission_rate: 5.0
      )
    end

    it 'calculates price for area in m2' do
      expect(project.price_for(50.0)).to eq(5000.0)
    end

    it 'calculates price for area in ft2' do
      project.measurement_unit = 'ft2'
      expected_area = 50.0 * 10.7639
      expect(project.price_for(50.0)).to be_within(0.01).of(expected_area * 100.0)
    end

    it 'calculates price for area in vara2' do
      project.measurement_unit = 'vara2'
      expected_area = 50.0 * 1.431
      expect(project.price_for(50.0)).to be_within(0.01).of(expected_area * 100.0)
    end
  end

  describe 'associations' do
    it 'has many lots' do
      project = described_class.new
      expect(project).to respond_to(:lots)
    end

    it 'destroys dependent lots' do
      project = described_class.create!(
        name: 'Test',
        description: 'Test',
        address: 'Test',
        price_per_square_unit: 100.0,
        measurement_unit: 'm2',
        interest_rate: 5.0,
        commission_rate: 5.0
      )
      lot = project.lots.create!(name: 'ToDestroy', length: 5.0, width: 5.0, price: 100.0, measurement_unit: 'm2',
                                 status: 'available')
      expect { project.destroy }.to change { Lot.exists?(lot.id) }.from(true).to(false)
    end
  end
end
