# frozen_string_literal: true

# app/controllers/concerns/sortable.rb

module Sortable
  extend ActiveSupport::Concern

  included do
    # Generic sorting application
    def apply_sorting(scope, params, sortable_fields)
      sort_param = params[:sort]
      return scope if sort_param.blank? || sortable_fields.blank?

      field, direction = parse_sort_param(sort_param)
      sort_column = resolve_sort_column(field, sortable_fields)
      return scope if sort_column.blank?

      orders = [order_clause(sort_column, direction)]
      tie_breaker = tie_breaker_clause(scope, sort_column, direction)
      orders << tie_breaker if tie_breaker

      scope.order(orders.join(', '))
    end

    def parse_sort_param(sort_param)
      field, direction = sort_param.to_s.split('-', 2)
      direction = direction&.downcase == 'desc' ? 'desc' : 'asc'
      [field, direction]
    end

    private

    def resolve_sort_column(field, sortable_fields)
      return if field.blank?

      case sortable_fields
      when Hash
        sortable_fields[field] || sortable_fields[field.to_sym] ||
          sortable_fields.values.find { |candidate| matches_field?(candidate, field) }
      else
        sortable_fields.find { |candidate| matches_field?(candidate, field) }
      end
    end

    def matches_field?(candidate, field)
      candidate.to_s == field || candidate.to_s.split('.').last == field
    end

    def order_clause(column, direction)
      "#{column} #{direction}"
    end

    def tie_breaker_clause(scope, column, direction)
      table_name = if column.to_s.include?('.')
                     column.to_s.split('.').first
                   else
                     scope.klass.table_name
                   end

      return unless table_name.present?

      "#{table_name}.id #{direction}"
    end
  end
end
