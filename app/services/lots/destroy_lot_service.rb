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
      project_id = @lot.project_id

      @lot.destroy

      # Invalidate cache after successful lot deletion
      # Since the lot is destroyed, we need to use a project-based invalidation
      Rails.cache.delete_matched("lots_index_#{project_id}_*")

      { success: true, message: 'Lote eliminado con éxito.' }
    rescue StandardError => e
      { success: false, errors: e.message }
    end
  end
end
