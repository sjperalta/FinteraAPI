# frozen_string_literal: true

# app/services/lots/destroy_lot_service.rb

module Lots
  class DestroyLotService
    def initialize(lot:)
      @lot = lot
    end

    def call
      @lot.destroy
      { success: true, message: 'Lote eliminado con éxito.' }
    rescue StandardError => e
      { success: false, errors: e.message }
    end
  end
end
