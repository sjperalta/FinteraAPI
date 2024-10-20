# app/services/lots/create_lot_service.rb

module Lots
  class CreateLotService
    def initialize(project:, lot_params:)
      @project = project
      @lot_params = lot_params
    end

    def call
      lot = @project.lots.build(@lot_params)
      if lot.save
        { success: true, lot: lot }
      else
        { success: false, errors: lot.errors.full_messages }
      end
    end
  end
end
