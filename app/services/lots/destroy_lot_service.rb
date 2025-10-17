# frozen_string_literal: true

# app/services/lots/destroy_lot_service.rb

module Lots
  # Service to destroy a lot
  class DestroyLotService
    include LotCacheInvalidation

    def initialize(lot:)
      @lot = lot
    end

    def call
      # Store project_id before destroying the lot
      # Capture a copy of the lot data we'll need for cache invalidation
      lot_for_cache = @lot.dup

      @lot.destroy

      # Use the shared invalidation implementation from LotCacheInvalidation
      invalidate_lot_cache(lot_for_cache)

      { success: true, message: 'Lote eliminado con éxito.' }
    rescue StandardError => e
      { success: false, errors: e.message }
    end
  end
end
