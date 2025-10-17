# frozen_string_literal: true

# app/services/lots/create_lot_service.rb

module Lots
  # Service to create a lot within a project
  class CreateLotService
    include LotCacheInvalidation

    def initialize(project:, lot_params:)
      @project = project
      @lot_params = lot_params
    end

    def call
      lot = @project.lots.build(@lot_params)
      if lot.save
        # Invalidate cache after successful lot creation
        invalidate_lot_cache(lot)

        { success: true, lot: }
      else
        { success: false, errors: lot.errors.full_messages }
      end
    end
  end
end
