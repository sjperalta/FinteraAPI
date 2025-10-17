# frozen_string_literal: true

module CreditScore
  # Service to calculate credit score using VantageScore model
  class CreditScoreCalculator
    def initialize(user)
      @user = user
    end

    def calculate
      payment_history = calculate_payment_history

      # Credit utilization: lower utilization is better. Convert utilization
      # (balance / credit * 100) into a positive score where 100 means no
      # utilization and 0 means fully utilized. This reduces the penalty for
      # moderate utilization.
      raw_utilization = calculate_credit_utilization
      credit_utilization = (100.0 - raw_utilization).clamp(0.0, 100.0)

      # Credit age: normalize years into a 0-100 score (10+ years => 100).
      # Apply the small boost for very new users first, then normalize so the
      # scale is comparable with other factors and doesn't overly penalize
      # newcomers.
      raw_age_years = calculate_credit_age
      boosted_age_years = adjust_credit_age_for_new_user(raw_age_years)
      credit_age = [(boosted_age_years / 10.0) * 100.0, 100.0].min.round(2)

      # Total accounts: map counts to 0-100 (10 or more accounts => 100).
      total_accounts = calculate_total_accounts
      total_accounts_score = [(total_accounts.to_f / 10.0) * 100.0, 100.0].min.round(2)

      # Combine the factors with slightly increased weight on payment history
      # and reduced weight on the raw age/accounts to penalize users less.
      credit_score = ((payment_history * 0.45) + (credit_utilization * 0.25) +
             (credit_age * 0.20) + (total_accounts_score * 0.10)).round

      # Store the calculated credit score in the user's record
      @user.update(credit_score:)
      user_id = @user.is_a?(User) ? @user.id : 'N/A'
      Rails.logger.info("Calculated credit score for User ID #{user_id}: #{credit_score}")

      credit_score
    end

    private

    def calculate_payment_history
      # Calculate payment history based on the user's contracts and payments
      contracts = @user.contracts.includes(:payments)
      total_payments = 0
      on_time_payments = 0

      contracts.each do |contract|
        contract.payments.each do |payment|
          next if payment.due_date.nil? || payment.payment_date.nil? # Skip if dates are nil

          total_payments += 1
          on_time_payments += 1 if payment.due_date >= payment.payment_date
        end
      end

      return 100 if total_payments.zero? # No payments, assume perfect history

      (on_time_payments.to_f / total_payments * 100).round
    end

    def calculate_credit_utilization
      contracts = @user.contracts
      total_credit = contracts.sum(&:amount).to_f
      total_balance = contracts.sum(&:balance).to_f

      return 0.0 if total_credit.zero?

      ((total_balance / total_credit) * 100.0).round(2) # Percentage used
    end

    def calculate_credit_age
      contracts = @user.contracts
      return 0.0 if contracts.empty?

      total_age_in_days = contracts.sum { |contract| (Date.today - contract.created_at.to_date).to_i }
      (total_age_in_days / contracts.size / 365.0).round(2) # Convert to years
    end

    def calculate_total_accounts
      @user.contracts.count
    end

    def adjust_credit_age_for_new_user(age_in_years)
      return age_in_years if age_in_years >= 1.0 || age_in_years.zero?

      # Boost small ages by 50% (e.g., 0.5 years -> 0.75 years) so new users
      # receive less penalty from a low credit age. Leave larger ages unchanged.
      (age_in_years * 1.5).round(2)
    end
  end
end
