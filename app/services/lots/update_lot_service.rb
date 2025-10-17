# frozen_string_literal: true

module Lots
  # Service to update a lot's attributes
  class UpdateLotService
    include LotCacheInvalidation

    def initialize(lot:, lot_params:)
      @lot = lot
      @lot_params = lot_params
    end

    def call
      if @lot.update(@lot_params)
        # Invalidate cache after successful lot update
        invalidate_lot_cache(@lot)

        { success: true, lot: @lot }
      else
        { success: false, errors: @lot.errors.full_messages }
      end
    end
  end
end
