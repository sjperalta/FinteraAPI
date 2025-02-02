module Lots
  class UpdateLotService
    def initialize(lot:, lot_params:)
      @lot = lot
      @lot_params = lot_params
    end

    def call
      return { success: false, errors: ['Invalid parameters'] } unless valid_params?

      if @lot.update(@lot_params)
        { success: true, lot: @lot }
      else
        { success: false, errors: @lot.errors.full_messages }
      end
    end

    private

    def valid_params?
      required_keys = %i[name length width price]
      required_keys.all? { |key| @lot_params.key?(key) && !@lot_params[key].nil? }
    end
  end
end
