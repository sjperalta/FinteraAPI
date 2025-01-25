# app/controllers/concerns/sortable.rb

module Sortable
  extend ActiveSupport::Concern

  included do
    # Generic sorting application
    def apply_sorting(scope, params, sortable_fields)
      if params[:sort].present?
        field, direction = params[:sort].split("-")
        if sortable_fields.include?(field) && %w[asc desc].include?(direction)
          scope = scope.order("#{field} #{direction}")
        end
      end
      scope
    end

    def parse_sort_param(sort_param)
      field, direction = sort_param.split('-')
      direction = direction.downcase == 'desc' ? 'desc' : 'asc'
      [field, direction]
    end
  end
end
