# frozen_string_literal: true

module Lots
  # Service to update a lot's attributes
  class UpdateLotService
    def initialize(lot:, lot_params:)
      @lot = lot
      @lot_params = lot_params
    end

    def call
      if @lot.update(@lot_params)
        { success: true, lot: @lot }
      else
        { success: false, errors: @lot.errors.full_messages }
      end
    end
  end
end
