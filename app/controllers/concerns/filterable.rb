# frozen_string_literal: true

# app/controllers/concerns/filterable.rb

module Filterable
  extend ActiveSupport::Concern

  included do
    # Generic filter application
    def apply_filters(scope, params, searchable_fields)
      model = scope.model.table_name

      # Apply status filter
      scope = apply_status_filter(scope, params[:status]) if params[:status].present?

      # Apply search filter
      if params[:search_term].present?
        search_term = "%#{params[:search_term].strip.downcase}%"
        searchable_conditions = searchable_fields.map { |field| "LOWER(#{model}.#{field}) LIKE :search" }.join(' OR ')
        scope = scope.where(searchable_conditions, search: search_term)
      end

      scope
    end

    private

    def apply_status_filter(scope, status_param)
      statuses = parse_statuses(status_param)
      statuses.any? ? scope.where(status: statuses) : scope
    end

    def parse_statuses(status_param)
      status_param = status_param.to_s.strip

      # Check if it's in the format [status1|status2|status3]
      if status_param.match?(/^\[.*\]$/)
        # Remove brackets and split by |
        status_param[1..-2].split('|').map(&:strip).map(&:downcase).reject(&:empty?)
      else
        # Single status
        [status_param.downcase]
      end
    end
  end
end
