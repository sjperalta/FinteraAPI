# frozen_string_literal: true

module Contracts
  # Service for handling capital repayment on contracts
  # When a user makes a capital repayment, we:
  # 1. Apply the prepayment to reduce the contract balance
  # 2. Then calculate the remaining amount, this serve to identify how many payments to reajust
  # 3. Identify the last pending payments that cover that remaining amount
  # 4. Mark those payments as "reajustment" since they will be recalculated
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
        # Apply prepayment; rollback on failure
        unless @contract.apply_prepayment(@amount)
          @errors.concat(@contract.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Mark payments and collect reajusted payments
        @reajusted_payments = mark_payments_for_reajustment

        # Trigger credit score update
        trigger_credit_score_update

        # Invalidate contracts index cache
        invalidate_contract_cache(@contract)
      end

      # Build successful response
      {
        success: true,
        errors: [],
        message: 'Amortización de capital registrada exitosamente',
        contract: @contract,
        reajusted_payments_count: @reajusted_payments&.size || 0,
        reajusted_payment_ids: @reajusted_payments&.map(&:id) || []
      }
    rescue StandardError => e
      Rails.logger.error("Capital repayment failed: #{e.message}")
      @errors << e.message
      failure_response
    end

    private

    def validate_amount
      if @amount <= 0
        @errors << 'El monto de amortización debe ser mayor a cero'
        return
      end

      return unless @amount > @contract.balance

      @errors << "El monto de amortización (#{@amount}) excede el balance pendiente (#{@contract.balance})"
    end

    # The contract.apply_prepayment method manages ledger entries and errors
    # def apply_prepayment is removed in favor of direct contract call in #call

    def mark_payments_for_reajustment
      # Get all pending payments ordered by due_date descending (last payments first)
      pending_payments = @contract.payments.pending.order(due_date: :desc)

      return [] if pending_payments.empty?

      # Calculate which payments to mark as reajustment
      # Use the remaining balance AFTER prepayment, not the original amount
      remaining_balance = @contract.reload.balance
      payments_to_reajust = []

      pending_payments.each do |payment|
        break if remaining_balance <= 0

        payments_to_reajust << payment
        remaining_balance -= payment.amount
      end

      # Mark selected payments as reajustment
      payments_to_reajust.each do |payment|
        payment.reajustment! if payment.may_reajustment?
      end

      payments_to_reajust
    end

    def trigger_credit_score_update
      UpdateCreditScoresJob.perform_later(@contract.applicant_user.id)
    end

    def success_response
      {
        success: true,
        message: 'Amortización de capital registrada exitosamente',
        contract: @contract,
        reajusted_payments_count: @reajusted_payments&.size || 0,
        reajusted_payments: @reajusted_payments || []
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
