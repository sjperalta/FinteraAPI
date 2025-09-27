# frozen_string_literal: true

# app/controllers/concerns/filterable.rb

# Concern to add filtering capabilities to controllers
module Filterable
  extend ActiveSupport::Concern

  # Constants for filter parsing
  MULTIPLE_STATUS_PATTERN = /^\[(.+)\]$/
  STATUS_SEPARATOR = '|'
  SEARCH_WILDCARD = '%'

  included do
    # Generic filter application with support for multiple filter types
    def apply_filters(scope, params, searchable_fields)
      return scope if params.blank?

      scope = apply_status_filter(scope, params[:status]) if params[:status].present?
      scope = apply_search_filter(scope, params[:search_term], searchable_fields) if params[:search_term].present?
      scope = apply_date_range_filter(scope, params) if date_range_params_present?(params)
      scope = apply_amount_range_filter(scope, params) if amount_range_params_present?(params)

      scope
    end

    private

    # Apply status filtering with support for single or multiple statuses
    def apply_status_filter(scope, status_param)
      statuses = parse_statuses(status_param)
      return scope if statuses.empty?

      scope.where(status: statuses)
    end

    # Apply text search across multiple fields including associations
    def apply_search_filter(scope, search_term, searchable_fields)
      return scope if search_term.blank? || searchable_fields.blank?

      sanitized_term = sanitize_search_term(search_term)
      scope_with_joins = ensure_associations_joined(scope, searchable_fields)
      search_conditions = build_search_conditions(scope_with_joins, searchable_fields)

      scope_with_joins.where(search_conditions, search: sanitized_term)
    end

    # Apply date range filtering
    def apply_date_range_filter(scope, params)
      scope_with_date_filters = scope

      if params[:start_date].present?
        start_date = parse_date(params[:start_date])
        scope_with_date_filters = scope_with_date_filters.where('created_at >= ?', start_date) if start_date
      end

      if params[:end_date].present?
        end_date = parse_date(params[:end_date])
        scope_with_date_filters = scope_with_date_filters.where('created_at <= ?', end_date.end_of_day) if end_date
      end

      scope_with_date_filters
    end

    # Apply amount range filtering
    def apply_amount_range_filter(scope, params)
      scope_with_amount_filters = scope

      if params[:min_amount].present?
        min_amount = parse_amount(params[:min_amount])
        scope_with_amount_filters = scope_with_amount_filters.where('amount >= ?', min_amount) if min_amount
      end

      if params[:max_amount].present?
        max_amount = parse_amount(params[:max_amount])
        scope_with_amount_filters = scope_with_amount_filters.where('amount <= ?', max_amount) if max_amount
      end

      scope_with_amount_filters
    end

    # Parse status parameter supporting both single and multiple statuses
    # Formats supported:
    # - Single: "pending"
    # - Multiple: "[pending|submitted|paid]"
    def parse_statuses(status_param)
      return [] if status_param.blank?

      normalized_param = status_param.to_s.strip

      if (match = normalized_param.match(MULTIPLE_STATUS_PATTERN))
        # Multiple statuses: [status1|status2|status3]
        match[1].split(STATUS_SEPARATOR)
                .map(&:strip)
                .map(&:downcase)
                .reject(&:empty?)
                .uniq
      else
        # Single status
        [normalized_param.downcase]
      end
    end

    # Build search conditions for multiple fields including associations
    def build_search_conditions(scope, searchable_fields)
      table_name = scope.model.table_name

      searchable_fields.map do |field|
        column_reference = resolve_field_reference(field, table_name, scope.model)
        build_field_condition(field, column_reference, scope.model)
      end.join(' OR ')
    end

    # Build appropriate condition based on field type
    def build_field_condition(field, column_reference, model)
      column_type = get_column_type(field, model)

      case column_type
      when :datetime, :timestamp, :date, :time, :integer, :decimal, :float, :numeric, :boolean
        # For non-text fields, convert to string first
        "LOWER(#{column_reference}::text) LIKE :search"
      else
        # For text fields, use LOWER directly
        "LOWER(#{column_reference}) LIKE :search"
      end
    end

    # Get the column type for a field
    def get_column_type(field, model)
      if field.include?('.')
        parts = field.split('.')

        # Check if it's a qualified table.column format (e.g., "contracts.created_at")
        if parts.length == 2 && parts[0] == model.table_name
          # Direct field with table qualification
          column_name = parts[1]
          column = model.columns.find { |col| col.name == column_name }
        else
          # Association field - navigate through the association chain
          current_model = model
          column_name = parts.last

          # Navigate through associations to find the final model
          (0..parts.length - 2).each do |i|
            association_name = parts[i]
            association = current_model.reflect_on_association(association_name.to_sym)

            unless association
              return :string # Default fallback if association not found
            end

            current_model = association.klass
          end

          # Get column type from the final model
          column = current_model.columns.find { |col| col.name == column_name }
        end
      else
        # Direct field without qualification
        column = model.columns.find { |col| col.name == field }
      end
      return column&.type || :string

      :string # Default fallback
    end

    # Ensure necessary associations are joined for searchable fields
    def ensure_associations_joined(scope, searchable_fields)
      associations_to_join = extract_associations(searchable_fields, scope.model)

      associations_to_join.reduce(scope) do |current_scope, association|
        # Only join if not already joined
        if current_scope.joins_values.none? { |join| join.to_s.include?(association.to_s) }
          current_scope.joins(association)
        else
          current_scope
        end
      end
    end

    # Extract association names from searchable fields
    def extract_associations(searchable_fields, model)
      associations = []

      searchable_fields.each do |field|
        next unless field.include?('.')

        parts = field.split('.')

        # Skip if it's a qualified table.column format (e.g., "contracts.created_at")
        next if parts.length == 2 && parts[0] == model.table_name

        association_path = parts[0..-2] # Remove the last part (column name)
        next if association_path.empty?

        # Build nested association path
        nested_association = build_nested_association(association_path, model)
        associations << nested_association if nested_association
      end

      associations.uniq
    end

    # Build nested association symbol for deep associations
    def build_nested_association(association_path, model)
      return nil if association_path.empty?

      return build_nested_hash(association_path, model) unless association_path.length == 1

      # Simple association like 'contract'
      association_name = association_path.first.to_sym
      return association_name if model.reflect_on_association(association_name)

      # Nested associations like 'contract.lot' or 'contract.applicant_user'

      nil
    end

    # Build nested hash for complex associations
    def build_nested_hash(path, model)
      return nil if path.empty?

      first_association = path.first.to_sym
      return nil unless model.reflect_on_association(first_association)

      if path.length == 1
        first_association
      else
        associated_model = model.reflect_on_association(first_association).klass
        nested = build_nested_hash(path[1..], associated_model)
        nested ? { first_association => nested } : first_association
      end
    end

    # Resolve field reference for both direct fields and association fields
    def resolve_field_reference(field, table_name, model)
      if field.include?('.')
        parts = field.split('.')

        # Check if it's already a qualified table.column format (e.g., "contracts.created_at")
        if parts.length == 2 && parts[0] == model.table_name
          # Already qualified with correct table name, return as-is
          field
        elsif parts.length == 2
          # Simple association like 'contract.balance'
          association_name = parts[0]
          column_name = parts[1]

          # Check if it's an association
          association = model.reflect_on_association(association_name.to_sym)
          return field unless association

          associated_table = association.klass.table_name
          "#{associated_table}.#{column_name}"

        # Assume it's a qualified table.column format

        else
          # Multi-part association like 'contract.lot.name' or 'contract.applicant_user.full_name'
          resolve_nested_association_field(parts, model)
        end
      else
        # Direct field on the main model
        "#{table_name}.#{field}"
      end
    end

    # Resolve nested association fields like 'contract.lot.name'
    def resolve_nested_association_field(parts, model)
      current_model = model

      # Navigate through the association chain
      (0..parts.length - 2).each do |i|
        association_name = parts[i]
        association = current_model.reflect_on_association(association_name.to_sym)

        unless association
          # If association not found, return the field as-is
          return parts.join('.')
        end

        current_model = association.klass
      end

      # Get the final table name and column
      final_table = current_model.table_name
      column_name = parts.last

      "#{final_table}.#{column_name}"
    end

    # Sanitize search term to prevent SQL injection and format for LIKE query
    def sanitize_search_term(search_term)
      cleaned_term = search_term.to_s.strip.downcase
      "#{SEARCH_WILDCARD}#{cleaned_term}#{SEARCH_WILDCARD}"
    end

    # Parse date parameter safely
    def parse_date(date_param)
      Date.parse(date_param.to_s)
    rescue ArgumentError
      Rails.logger.warn("Invalid date parameter: #{date_param}")
      nil
    end

    # Parse amount parameter safely
    def parse_amount(amount_param)
      BigDecimal(amount_param.to_s)
    rescue ArgumentError, TypeError
      Rails.logger.warn("Invalid amount parameter: #{amount_param}")
      nil
    end

    # Check if date range parameters are present
    def date_range_params_present?(params)
      params[:start_date].present? || params[:end_date].present?
    end

    # Check if amount range parameters are present
    def amount_range_params_present?(params)
      params[:min_amount].present? || params[:max_amount].present?
    end
  end
end
