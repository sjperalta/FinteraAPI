# frozen_string_literal: true

# app/services/contracts/cancel_contract_service.rb

module Contracts
  # Service to handle contract cancellation and related lot status update.
  class CancelContractService
    include ContractCacheInvalidation

    def initialize(contract:, current_user: nil, reason: nil)
      @contract = contract
      @current_user = current_user
      @reason = reason
    end

    def call
      return { success: false, errors: ['Contract cannot be cancelled in current state'] } unless @contract.may_cancel?

      ActiveRecord::Base.transaction do
        # Set current user in thread for logging
        Thread.current[:current_user] = @current_user

        # Add custom reason if provided
        if @reason.present?
          cancellation_note = "Reason: #{@reason}"
          @contract.note = if @contract.note.present?
                             "#{@contract.note}\n#{cancellation_note}"
                           else
                             cancellation_note
                           end
          @contract.save!
        end

        @contract.cancel!

        # Invalidate contracts cache after successful cancellation
        invalidate_contract_cache(@contract)

        { success: true, message: 'Contrato cancelado exitosamente', contract: @contract }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to cancel contract #{@contract.id}: #{e.message}"
      { success: false, errors: [e.message] }
    ensure
      Thread.current[:current_user] = nil
    end
  end
end
