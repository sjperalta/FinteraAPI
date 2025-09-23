# frozen_string_literal: true

require 'csv'

module Projects
  # Service to import projects and their associated lots from a CSV file.
  class ImportService
    attr_reader :errors

    def initialize(file:, options: {}, current_user: nil)
      @file = file
      @update_existing = truthy?(options['update_existing'])
      @skip_duplicates = truthy?(options['skip_duplicates'])
      @current_user = current_user
      reset_counts
      @errors = []
    end

    def call
      parse_csv.each_with_index do |row, idx|
        process_row(row.to_hash, idx + 1)
      end
      result_hash
    end

    private

    def reset_counts
      @imported_projects = 0
      @updated_projects = 0
      @skipped_projects = 0
      @imported_lots = 0
      @updated_lots = 0
      @skipped_lots = 0
    end

    def result_hash
      {
        imported_projects: @imported_projects,
        updated_projects: @updated_projects,
        skipped_projects: @skipped_projects,
        imported_lots: @imported_lots,
        updated_lots: @updated_lots,
        skipped_lots: @skipped_lots,
        errors: @errors
      }
    end

    def truthy?(v)
      [true, 1, '1', 'true'].include?(v)
    end

    def parse_csv
      text = @file.respond_to?(:read) ? @file.read : File.read(@file.path)
      CSV.parse(text, headers: true, skip_blanks: true)
    rescue CSV::MalformedCSVError => e
      raise StandardError, "Malformed CSV: #{e.message}"
    end

    def process_row(raw_row, row_number)
      row, field_errors = normalize_row(raw_row)

      # If parsing produced field errors, record and skip entirely
      unless field_errors.empty?
        @errors << { row: row_number, error: 'Field parse errors', details: field_errors }
        return
      end

      ActiveRecord::Base.transaction do
        project = find_or_build_project(row)
        persisted_before = project.persisted?

        if persisted_before
          if @update_existing
            assign_project_attributes(project, row)
            project.save!
            @updated_projects += 1
          else
            @skipped_projects += 1
          end
        else
          assign_project_attributes(project, row)
          project.save!
          @imported_projects += 1
        end

        # Process lot if lot_name, lot_width, and lot_length are present
        process_lot(project, row, row_number) if row['lot_name'].present? &&
                                                 row['lot_width'].present? &&
                                                 row['lot_length'].present?
      end
    rescue StandardError => e
      @errors << { row: row_number, error: e.message }
    end

    # ---------- Project handling ----------

    def find_or_build_project(row)
      if row['guid'].present?
        Project.find_or_initialize_by(guid: row['guid'])
      else
        Project.find_or_initialize_by(name: row['name'], address: row['address'])
      end
    end

    def assign_project_attributes(project, row)
      project.assign_attributes({
        name: row['name'],
        description: row['description'],
        project_type: row['project_type'],
        address: row['address'],
        price_per_square_unit: row['price_per_square_unit'],
        measurement_unit: row['measurement_unit'],
        interest_rate: row['interest_rate'],
        commission_rate: row['commission_rate'],
        delivery_date: row['delivery_date'],
        guid: row['guid']
      }.compact)
    end

    # ---------- Lot handling ----------

    def process_lot(project, row, row_number)
      # Find lot by name only (since lots table doesn't have guid column)
      lot = project.lots.find_or_initialize_by(name: row['lot_name'])
      persisted_before = lot.persisted?

      assign_lot_attributes(lot, project, row)
      lot.save!

      if persisted_before
        @updated_lots += 1
      else
        @imported_lots += 1
      end
    rescue StandardError => e
      @errors << { row: row_number, entity: 'lot', name: row['lot_name'], error: e.message }
    end

    def assign_lot_attributes(lot, project, row)
      attributes = {
        name: row['lot_name'],
        length: row['lot_length'],
        width: row['lot_width'],
        measurement_unit: row['measurement_unit'] || project.measurement_unit,
        address: row['lot_address'] || '',
        override_price: row['lot_override_price']
      }

      lot.assign_attributes(attributes.compact)
    end

    # ---------- Row normalization ----------

    DECIMAL_FIELDS = %w[
      price_per_square_unit interest_rate commission_rate
      lot_length lot_width lot_override_price
    ].freeze
    INTEGER_FIELDS = %w[lot_count].freeze
    DATE_FIELDS = %w[delivery_date].freeze

    def normalize_row(raw)
      normalized = {}
      field_errors = []

      raw.each do |k, v|
        next if k.nil?

        key = k.to_s.downcase
        val = v.is_a?(String) ? v.strip : v
        next if val.blank?

        begin
          normalized[key] = cast_value(key, val)
        rescue StandardError => e
          field_errors << "#{key}: #{e.message}"
        end
      end

      [normalized, field_errors]
    end

    def cast_value(key, val)
      return parse_decimal(val) if DECIMAL_FIELDS.include?(key)
      return parse_integer(val) if INTEGER_FIELDS.include?(key)
      return parse_date(val) if DATE_FIELDS.include?(key)

      val
    end

    def parse_decimal(v)
      BigDecimal(v.to_s)
    rescue ArgumentError
      raise "invalid decimal '#{v}'"
    end

    def parse_integer(v)
      Integer(v)
    rescue ArgumentError
      raise "invalid integer '#{v}'"
    end

    def parse_date(v)
      Date.parse(v.to_s)
    rescue ArgumentError
      raise "invalid date '#{v}'"
    end
  end
end
