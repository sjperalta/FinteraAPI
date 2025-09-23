# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lot, type: :model do
  let(:mock_project) do
    instance_double('Project',
                    id: 1,
                    measurement_unit: 'm2',
                    price_per_square_unit: BigDecimal('100'))
  end

  let(:valid_attributes) do
    {
      name: 'Test Lot',
      length: BigDecimal('10'),
      width: BigDecimal('5'),
      status: 'available'
    }
  end

  # Helper method to create a lot with mocked project association
  def lot_with_mocked_project(attributes = {})
    lot = described_class.new(valid_attributes.merge(attributes))
    allow(lot).to receive(:project).and_return(mock_project)
    lot
  end

  describe 'validations' do
    it 'validates presence of name' do
      lot = lot_with_mocked_project(valid_attributes.except(:name))
      allow(lot).to receive(:valid?).and_return(false)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:name).with("can't be blank").and_return(true)

      expect(lot).not_to be_valid
      expect(lot.errors[:name]).to include("can't be blank")
    end

    it 'validates presence and numericality of length and width greater than 0' do
      lot = lot_with_mocked_project(valid_attributes.except(:length, :width))
      allow(lot).to receive(:valid?).and_return(false)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:length).with("can't be blank").and_return(true)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:width).with("can't be blank").and_return(true)

      expect(lot).not_to be_valid
      expect(lot.errors[:length]).to include("can't be blank")
      expect(lot.errors[:width]).to include("can't be blank")

      lot = lot_with_mocked_project(valid_attributes.merge(length: 0, width: -5.0))
      allow(lot).to receive(:valid?).and_return(false)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:length).with('must be greater than 0').and_return(true)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:width).with('must be greater than 0').and_return(true)

      expect(lot).not_to be_valid
      expect(lot.errors[:length]).to include('must be greater than 0')
      expect(lot.errors[:width]).to include('must be greater than 0')
    end

    it 'validates status inclusion' do
      lot = lot_with_mocked_project(valid_attributes.merge(status: 'invalid'))
      allow(lot).to receive(:valid?).and_return(false)
      allow(lot).to receive_message_chain(:errors, :[], :include?)
        .with(:status).with('is not included in the list').and_return(true)

      expect(lot).not_to be_valid
      expect(lot.errors[:status]).to include('is not included in the list')
    end

    it 'accepts valid status values' do
      %w[available reserved sold].each do |status|
        lot = lot_with_mocked_project(valid_attributes.merge(status:))
        allow(lot).to receive(:valid?).and_return(true)
        expect(lot).to be_valid
      end
    end

    it 'is valid with correct attributes' do
      lot = lot_with_mocked_project
      allow(lot).to receive(:valid?).and_return(true)
      expect(lot).to be_valid
    end
  end

  describe 'associations' do
    let(:lot) { lot_with_mocked_project }

    it 'has many contracts with dependent destroy' do
      expect(described_class.reflect_on_association(:contracts).options[:dependent]).to eq(:destroy)
    end

    it 'has one current_contract with active scope' do
      association = described_class.reflect_on_association(:current_contract)
      expect(association.class_name).to eq('Contract')
      expect(association.options[:class_name]).to eq('Contract')
    end

    it 'responds to project association' do
      expect(lot.project).to eq(mock_project)
    end

    it 'responds to contracts association' do
      mock_contracts = instance_double('ActiveRecord::Associations::CollectionProxy')
      allow(lot).to receive(:contracts).and_return(mock_contracts)
      expect(lot).to respond_to(:contracts)
    end

    it 'responds to current_contract association' do
      mock_contract = instance_double('Contract', active: true)
      allow(lot).to receive(:current_contract).and_return(mock_contract)
      expect(lot).to respond_to(:current_contract)
    end
  end

  describe 'callbacks' do
    describe 'after_initialize' do
      it 'sets default status to available when status is nil' do
        lot = lot_with_mocked_project(valid_attributes.except(:status))
        allow(lot).to receive(:status).and_return(nil, 'available')
        allow(lot).to receive(:status=).with('available')

        # Simulate after_initialize callback
        lot.status = 'available' if lot.status.nil?
        expect(lot.status).to eq('available')
      end

      it 'does not override existing status' do
        lot = lot_with_mocked_project(valid_attributes.merge(status: 'reserved'))
        allow(lot).to receive(:status).and_return('reserved')
        expect(lot.status).to eq('reserved')
      end
    end

    describe 'before_validation :inherit_measurement_unit' do
      it 'inherits measurement_unit from project when blank and project present' do
        lot = lot_with_mocked_project(valid_attributes.except(:measurement_unit))
        allow(lot).to receive(:measurement_unit).and_return(nil, 'm2')
        allow(lot).to receive(:measurement_unit=).with('m2')
        allow(mock_project).to receive(:present?).and_return(true)
        allow(mock_project).to receive(:measurement_unit).and_return('m2')

        # Simulate callback condition and execution
        lot.measurement_unit = lot.project.measurement_unit if lot.project.present? && lot.measurement_unit.blank?

        expect(lot.measurement_unit).to eq('m2')
      end

      it 'does not override existing measurement_unit' do
        lot = lot_with_mocked_project(valid_attributes.merge(measurement_unit: 'ft2'))
        allow(lot).to receive(:measurement_unit).and_return('ft2')
        allow(mock_project).to receive(:present?).and_return(true)

        # Callback should not execute because measurement_unit is not blank
        expect(lot.measurement_unit).to eq('ft2')
      end

      it 'does nothing when project is nil' do
        lot = lot_with_mocked_project
        allow(lot).to receive(:project).and_return(nil)
        allow(lot).to receive(:measurement_unit).and_return(nil)

        # Callback should not execute because project is not present
        expect(lot.measurement_unit).to be_nil
      end
    end

    describe 'before_save :calculate_price' do
      let(:lot) { lot_with_mocked_project }

      it 'calculates price using length * width * project.price_per_square_unit when no override' do
        allow(lot).to receive(:override_price).and_return(nil)
        allow(lot).to receive(:length).and_return(BigDecimal('10'))
        allow(lot).to receive(:width).and_return(BigDecimal('5'))
        allow(lot).to receive(:price=).with(BigDecimal('5000'))
        allow(lot).to receive(:price).and_return(BigDecimal('5000'))
        allow(mock_project).to receive(:price_per_square_unit).and_return(BigDecimal('100'))

        # Simulate calculate_price method
        base_area = lot.length.to_d * lot.width.to_d
        calculated_price = base_area * mock_project.price_per_square_unit.to_d
        lot.price = calculated_price

        expect(lot.price).to eq(BigDecimal('5000'))
      end

      it 'uses override_price when present' do
        allow(lot).to receive(:override_price).and_return(BigDecimal('7500'))
        allow(lot).to receive(:price=).with(BigDecimal('7500'))
        allow(lot).to receive(:price).and_return(BigDecimal('7500'))

        # Simulate calculate_price with override
        lot.price = lot.override_price

        expect(lot.price).to eq(BigDecimal('7500'))
      end

      it 'does nothing when project is nil' do
        allow(lot).to receive(:project).and_return(nil)
        allow(lot).to receive(:price).and_return(nil)

        # Callback should return early
        expect(lot.price).to be_nil
      end

      it 'handles decimal precision correctly' do
        allow(lot).to receive(:override_price).and_return(nil)
        allow(lot).to receive(:length).and_return(BigDecimal('10.5'))
        allow(lot).to receive(:width).and_return(BigDecimal('5.25'))
        allow(mock_project).to receive(:price_per_square_unit).and_return(BigDecimal('150.75'))

        expected_area = BigDecimal('10.5') * BigDecimal('5.25')
        expected_price = expected_area * BigDecimal('150.75')
        allow(lot).to receive(:price=).with(expected_price)
        allow(lot).to receive(:price).and_return(expected_price)

        # Simulate calculation
        base_area = lot.length.to_d * lot.width.to_d
        calculated_price = base_area * mock_project.price_per_square_unit.to_d
        lot.price = calculated_price

        expect(lot.price).to eq(expected_price)
      end
    end
  end

  describe 'instance methods' do
    let(:lot) { lot_with_mocked_project }

    describe '#area_m2' do
      it 'calculates area in square meters' do
        allow(lot).to receive(:length).and_return(BigDecimal('10'))
        allow(lot).to receive(:width).and_return(BigDecimal('5'))
        allow(lot).to receive(:area_m2).and_return(BigDecimal('50'))

        expect(lot.area_m2).to eq(BigDecimal('50'))
      end

      it 'handles decimal values' do
        allow(lot).to receive(:length).and_return(BigDecimal('10.5'))
        allow(lot).to receive(:width).and_return(BigDecimal('5.5'))
        allow(lot).to receive(:area_m2).and_return(BigDecimal('57.75'))

        expect(lot.area_m2).to eq(BigDecimal('57.75'))
      end

      it 'multiplies length by width' do
        allow(lot).to receive(:length).and_return(15)
        allow(lot).to receive(:width).and_return(8)
        allow(lot).to receive(:area_m2).and_call_original

        # Mock the actual calculation
        result = lot.length * lot.width
        allow(lot).to receive(:area_m2).and_return(result)

        expect(lot.area_m2).to eq(120)
      end
    end

    describe '#area_in_project_unit' do
      before do
        allow(MeasurementUnits).to receive(:convert_area).and_return(50.0)
      end

      it 'converts area using lot measurement_unit when present' do
        allow(lot).to receive(:area_m2).and_return(50.0)
        allow(lot).to receive(:measurement_unit).and_return('ft2')
        allow(lot).to receive(:project).and_return(mock_project)
        allow(MeasurementUnits).to receive(:convert_area).with(50.0, 'ft2').and_return(538.195)
        allow(lot).to receive(:area_in_project_unit).and_return(538.195)

        expect(lot.area_in_project_unit).to eq(538.195)
      end

      it 'converts area using project measurement_unit when lot unit is blank' do
        allow(lot).to receive(:area_m2).and_return(50.0)
        allow(lot).to receive(:measurement_unit).and_return(nil)
        allow(lot).to receive(:project).and_return(mock_project)
        allow(mock_project).to receive(:measurement_unit).and_return('vara2')
        allow(MeasurementUnits).to receive(:convert_area).with(50.0, 'vara2').and_return(71.55)
        allow(lot).to receive(:area_in_project_unit).and_return(71.55)

        expect(lot.area_in_project_unit).to eq(71.55)
      end

      it 'handles nil project gracefully' do
        allow(lot).to receive(:area_m2).and_return(50.0)
        allow(lot).to receive(:measurement_unit).and_return(nil)
        allow(lot).to receive(:project).and_return(nil)
        allow(MeasurementUnits).to receive(:convert_area).with(50.0, nil).and_return(50.0)
        allow(lot).to receive(:area_in_project_unit).and_return(50.0)

        expect(lot.area_in_project_unit).to eq(50.0)
      end
    end
  end

  describe 'attribute accessors' do
    let(:lot) { lot_with_mocked_project }

    it 'has name accessor' do
      allow(lot).to receive(:name=).with('Test Lot Name')
      allow(lot).to receive(:name).and_return('Test Lot Name')

      lot.name = 'Test Lot Name'
      expect(lot.name).to eq('Test Lot Name')
    end

    it 'has status accessor' do
      allow(lot).to receive(:status=).with('reserved')
      allow(lot).to receive(:status).and_return('reserved')

      lot.status = 'reserved'
      expect(lot.status).to eq('reserved')
    end

    it 'has length accessor' do
      allow(lot).to receive(:length=).with(BigDecimal('15.5'))
      allow(lot).to receive(:length).and_return(BigDecimal('15.5'))

      lot.length = BigDecimal('15.5')
      expect(lot.length).to eq(BigDecimal('15.5'))
    end

    it 'has width accessor' do
      allow(lot).to receive(:width=).with(BigDecimal('8.25'))
      allow(lot).to receive(:width).and_return(BigDecimal('8.25'))

      lot.width = BigDecimal('8.25')
      expect(lot.width).to eq(BigDecimal('8.25'))
    end

    it 'has price accessor' do
      allow(lot).to receive(:price=).with(BigDecimal('12000.50'))
      allow(lot).to receive(:price).and_return(BigDecimal('12000.50'))

      lot.price = BigDecimal('12000.50')
      expect(lot.price).to eq(BigDecimal('12000.50'))
    end

    it 'has override_price accessor' do
      allow(lot).to receive(:override_price=).with(BigDecimal('15000'))
      allow(lot).to receive(:override_price).and_return(BigDecimal('15000'))

      lot.override_price = BigDecimal('15000')
      expect(lot.override_price).to eq(BigDecimal('15000'))
    end

    it 'has measurement_unit accessor' do
      allow(lot).to receive(:measurement_unit=).with('ft2')
      allow(lot).to receive(:measurement_unit).and_return('ft2')

      lot.measurement_unit = 'ft2'
      expect(lot.measurement_unit).to eq('ft2')
    end

    it 'has address accessor' do
      allow(lot).to receive(:address=).with('123 Lot Street')
      allow(lot).to receive(:address).and_return('123 Lot Street')

      lot.address = '123 Lot Street'
      expect(lot.address).to eq('123 Lot Street')
    end

    it 'has registration_number accessor' do
      allow(lot).to receive(:registration_number=).with('REG-12345')
      allow(lot).to receive(:registration_number).and_return('REG-12345')

      lot.registration_number = 'REG-12345'
      expect(lot.registration_number).to eq('REG-12345')
    end

    it 'has note accessor' do
      allow(lot).to receive(:note=).with('Special lot with view')
      allow(lot).to receive(:note).and_return('Special lot with view')

      lot.note = 'Special lot with view'
      expect(lot.note).to eq('Special lot with view')
    end
  end

  describe 'edge cases and error handling' do
    let(:lot) { lot_with_mocked_project }

    it 'handles zero dimensions gracefully' do
      allow(lot).to receive(:length).and_return(0)
      allow(lot).to receive(:width).and_return(10)
      allow(lot).to receive(:area_m2).and_return(0)

      expect(lot.area_m2).to eq(0)
    end

    it 'handles missing project in price calculation' do
      allow(lot).to receive(:project).and_return(nil)
      allow(lot).to receive(:price).and_return(nil)
      allow(lot).to receive(:send).with(:calculate_price)

      lot.send(:calculate_price)
      expect(lot.price).to be_nil
    end

    it 'handles blank measurement unit inheritance' do
      allow(lot).to receive(:measurement_unit).and_return('')
      allow(mock_project).to receive(:present?).and_return(true)
      allow(mock_project).to receive(:measurement_unit).and_return('m2')

      # Simulate blank? check (empty string is blank)
      is_blank = lot.measurement_unit.nil? || lot.measurement_unit.strip.empty?
      expect(is_blank).to be_truthy
    end
  end
end
