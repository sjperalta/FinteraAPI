# frozen_string_literal: true

# app/controllers/concerns/filterable.rb

module Filterable
  extend ActiveSupport::Concern

  included do
    # Generic filter application
    def apply_filters(scope, params, searchable_fields)
      model = scope.model.table_name

      # Apply status filter
      scope = scope.where(status: params[:status].downcase) if params[:status].present?

      # Apply search filter
      if params[:search_term].present?
        search_term = "%#{params[:search_term].strip.downcase}%"
        searchable_conditions = searchable_fields.map { |field| "LOWER(#{model}.#{field}) LIKE :search" }.join(' OR ')
        scope = scope.where(searchable_conditions, search: search_term)
      end

      scope
    end
  end
end
