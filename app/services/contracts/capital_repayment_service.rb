# frozen_string_literal: true

module Contracts
  # Service for handling capital repayment on contracts
  #
  # Business Logic:
  # When a user makes a capital repayment, we:
  # 1. Apply the prepayment to reduce the contract balance
  # 2. Mark the last N pending payments as "readjustment" where N is determined by
  #    how many COMPLETE payments the repayment amount would cover (no partial payments)
  #
  # Example Scenarios:
  # - Contract has 5 payments of 5,000 each (P1-P5), balance = 25,000
  # - User pays 20,000 capital repayment
  # - Remaining balance = 5,000
  # - The 20,000 covers exactly the last 4 payments (P5+P4+P3+P2 = 20,000)
  # - Result: Mark P5, P4, P3, P2 as "readjustment"
  #
  # Another example (partial payment scenario):
  # - User pays 17,000 capital repayment
  # - The 17,000 would cover P5+P4+P3 = 15,000 (with 2,000 left)
  # - Adding P2 (5,000) would exceed the repayment (17,000 < 20,000)
  # - Result: Mark ONLY P5, P4, P3 as "readjustment" (we don't mark partial payments)
  #
  # Performance Note: Uses update_all for bulk status updates to avoid N state machine
  # callbacks when marking multiple payments as readjustment
  class CapitalRepaymentService
    include ContractCacheInvalidation

    def initialize(contract:, amount:, current_user:)
      @contract = contract
      @amount = amount.to_d
      @current_user = current_user
      @errors = []
    end

    def call
      validate_amount
      return failure_response if @errors.any?

      ActiveRecord::Base.transaction do
        # Step 1: Apply prepayment to reduce contract balance
        # This creates a ledger entry and updates the contract balance
        unless @contract.apply_prepayment(@amount)
          @errors.concat(@contract.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Step 2: Mark the last N payments as "readjustment"
        # where N is determined by how many payments the repayment amount covers
        @readjusted_payments = mark_payments_for_readjustment

        # Step 3: Trigger credit score update for the contract owner
        trigger_credit_score_update

        # Step 4: Invalidate cached contract data for affected users
        invalidate_contract_cache(@contract)
      end

      # Build successful response
      success_response
    rescue StandardError => e
      Rails.logger.error("Capital repayment failed: #{e.message}")
      @errors << e.message
      failure_response
    end

    private

    def validate_amount
      # Ensure repayment amount is positive
      if @amount <= 0
        @errors << 'El monto de amortización debe ser mayor a cero'
        return
      end

      # Ensure repayment doesn't exceed the current contract balance
      return unless @amount > @contract.balance

      @errors << "El monto de amortización (#{@amount}) excede el balance pendiente (#{@contract.balance})"
    end

    # The contract.apply_prepayment method manages ledger entries and errors
    # def apply_prepayment is removed in favor of direct contract call in #call

    def mark_payments_for_readjustment
      # Get all pending payments ordered by due_date descending (last payments first)
      pending_payments = @contract.payments.pending.order(due_date: :desc)

      return [] if pending_payments.empty?

      # Mark payments starting from the last one until the repayment amount is covered
      # Example: If repayment is 17,000 and payments are 5,000 each:
      #   - P5 (5,000): covered amount = 5,000, remaining to cover = 12,000
      #   - P4 (5,000): covered amount = 10,000, remaining to cover = 7,000
      #   - P3 (5,000): covered amount = 15,000, remaining to cover = 2,000
      #   - P2 (5,000): covered amount = 20,000, remaining to cover = -3,000 (would go negative, stop before marking P2)
      # Result: Mark P5, P4, P3 (the last 3 payments - we don't mark partial payments)
      amount_to_cover = @amount
      payments_to_reajust = []

      pending_payments.each do |payment|
        # Stop if adding this payment would exceed the repayment amount
        # We don't mark partial payments - only complete ones
        break if (amount_to_cover - payment.amount).negative?

        # Mark this payment for readjustment
        payments_to_reajust << payment
        amount_to_cover -= payment.amount
      end

      # Performance optimization: Use update_all for bulk status update
      # This avoids N state machine callbacks and reduces database round trips
      # Note: This bypasses AASM callbacks, so ensure no critical logic exists in those callbacks
      if payments_to_reajust.any?
        payment_ids = payments_to_reajust.map(&:id)
        Payment.where(id: payment_ids).update_all(status: 'readjustment')

        # Reload the payments to reflect the updated status
        payments_to_reajust.each(&:reload)
      end

      payments_to_reajust
    end

    def trigger_credit_score_update
      UpdateCreditScoresJob.perform_later(@contract.applicant_user.id)
    end

    def success_response
      {
        success: true,
        errors: [],
        message: 'Amortización de capital registrada exitosamente',
        contract: @contract,
        readjusted_payments_count: @readjusted_payments&.size || 0,
        readjusted_payments: @readjusted_payments || []
      }
    end

    def failure_response
      {
        success: false,
        errors: @errors
      }
    end
  end
end
