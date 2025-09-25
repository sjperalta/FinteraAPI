# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe Projects::ImportService, type: :service do
  let(:csv_header) do
    'name,description,project_type,address,price_per_square_unit,measurement_unit,interest_rate,commission_rate,delivery_date,guid,lot_name,lot_length,lot_width,measurement_unit,address,lot_override_price'
  end

  # Stub Lot callbacks but ensure price gets calculated
  before do
    allow_any_instance_of(Lot).to receive(:inherit_measurement_unit)
    allow_any_instance_of(Lot).to receive(:calculate_price) do |lot|
      lot.price = if lot.length.present? && lot.width.present? && lot.project.price_per_square_unit.present?
                    (lot.length * lot.width * lot.project.price_per_square_unit).to_d
                  elsif lot.override_price.present?
                    lot.override_price
                  else
                    BigDecimal('0') # Default price to avoid NOT NULL violation
                  end
    end
  end

  # Helper: writes CSV content to a Tempfile and returns the file handle.
  def csv_file_with(content)
    file = Tempfile.new(['projects', '.csv'])
    file.write(content)
    file.rewind
    file
  end

  describe '#call' do
    context 'when importing new projects and lots' do
      let(:csv_content) do
        <<~CSV
          #{csv_header}
          "Test Project","Test Description","residential","123 Test St",100.0,"m2",5.0,2.0,2025-12-31,"PROJECT-GUID","Lot 1",10,20,"m2","Lot 1 Address",5000.50
        CSV
      end

      it 'creates a new project and its lot' do
        file = csv_file_with(csv_content)
        service = described_class.new(file:, options: {})

        result = service.call

        expect(result[:imported_projects]).to eq(1)
        expect(result[:imported_lots]).to eq(1)
        expect(result[:updated_projects]).to eq(0)
        expect(result[:errors]).to be_empty

        project = Project.find_by(guid: 'PROJECT-GUID')
        expect(project.name).to eq('Test Project')

        lot = project.lots.find_by(name: 'Lot 1')
        expect(lot).to be_present
        expect(lot.name).to eq('Lot 1')
        expect(lot.price).to eq(BigDecimal('20000')) # 10 * 20 * 100 = 20000
      ensure
        file.close
        file.unlink
      end
    end

    context 'when update_existing option is enabled' do
      let(:csv_content) do
        <<~CSV
          #{csv_header}
          "Existing Project","Updated Description","residential","456 Main St",150.0,"m2",6.0,3.0,2025-11-30,"EXISTING-GUID","Lot A",15,25,"m2","Lot A Address",4500.00
        CSV
      end

      before do
        # Create an existing project with the same guid but different description.
        Project.create!(
          name: 'Existing Project',
          description: 'Old Description',
          project_type: 'residential',
          address: '456 Main St',
          price_per_square_unit: 150.0,
          measurement_unit: 'm2',
          interest_rate: 6.0,
          commission_rate: 3.0,
          delivery_date: Date.parse('2025-11-30'),
          guid: 'EXISTING-GUID'
        )
      end

      it 'updates the existing project' do
        file = csv_file_with(csv_content)
        service = described_class.new(file:, options: { 'update_existing' => '1' })

        result = service.call

        expect(result[:updated_projects]).to eq(1)
        # Since the project already existed it is not imported.
        expect(result[:imported_projects]).to eq(0)

        project = Project.find_by(guid: 'EXISTING-GUID')
        expect(project).to be_present
        expect(project.description).to eq('Updated Description')
      ensure
        file.close
        file.unlink
      end
    end

    context 'when skip_duplicates option is enabled' do
      let(:csv_content) do
        <<~CSV
          #{csv_header}
          "Duplicate Project","Some Description","residential","789 Elm St",200.0,"m2",7.0,4.0,2025-10-31,"DUPLICATE-GUID","Lot Dup",12,18,"m2","Lot Dup Address",3600.00
        CSV
      end

      before do
        # Create an existing project that should be skipped
        Project.create!(
          name: 'Duplicate Project',
          description: 'Existing Desc',
          project_type: 'residential',
          address: '789 Elm St',
          lot_count: 1,
          price_per_square_unit: 200.0,
          measurement_unit: 'm2',
          interest_rate: 7.0,
          commission_rate: 4.0,
          delivery_date: Date.parse('2025-10-31'),
          guid: 'DUPLICATE-GUID'
        )
      end

      it 'skips updating the project but still creates the lot' do
        file = csv_file_with(csv_content)
        service = described_class.new(file:, options: { 'skip_duplicates' => '1' })

        result = service.call

        expect(result[:skipped_projects]).to eq(1)
        # The project exists so no update occurs, but the lot should be created.
        expect(result[:imported_lots]).to eq(1)

        project = Project.find_by(guid: 'DUPLICATE-GUID')
        expect(project).to be_present
        lot = project.lots.find_by(name: 'Lot Dup')
        expect(lot).to be_present
        expect(lot.name).to eq('Lot Dup')
      ensure
        file.close
        file.unlink
      end
    end

    context 'when given an invalid row' do
      let(:invalid_csv) do
        <<~CSV
          #{csv_header}
          "Bad Project","Desc","residential","Some Address",1,invalid_number,"m2",5.0,2.0,2025-12-31,"BAD-GUID","Lot Bad",10,20,"m2","Lot Bad Address",2000.00
        CSV
      end

      it 'collects errors for the invalid row' do
        file = csv_file_with(invalid_csv)
        service = described_class.new(file:, options: {})

        result = service.call

        expect(result[:errors]).not_to be_empty
        expect(result[:imported_projects]).to eq(0)
      ensure
        file.close
        file.unlink
      end
    end

    context 'when lot has explicit price' do
      let(:csv_content) do
        <<~CSV
          #{csv_header}
          "Price Test Project","Test Description","residential","123 Test St",100.0,"m2",5.0,2.0,2025-12-31,"PRICE-TEST-GUID","Lot Price",10,20,"m2","Lot 1",5000.50
        CSV
      end

      it 'uses the explicit price from CSV' do
        file = csv_file_with(csv_content)
        service = described_class.new(file:, options: {})

        result = service.call

        expect(result[:imported_projects]).to eq(1)
        expect(result[:imported_lots]).to eq(1)
        expect(result[:errors]).to be_empty

        project = Project.find_by(guid: 'PRICE-TEST-GUID')
        lot = project.lots.find_by(name: 'Lot Price')
        expect(lot.override_price).to eq(BigDecimal('5000.50'))
        expect(lot.price).to eq(BigDecimal('20000.0'))
      ensure
        file.close
        file.unlink
      end
    end
  end
end
