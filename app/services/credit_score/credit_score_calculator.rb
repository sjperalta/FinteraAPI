# frozen_string_literal: true

module CreditScore
  # Service to calculate credit score using VantageScore model
  class CreditScoreCalculator
    def initialize(user)
      @user = user
    end

    def calculate
      payment_history = calculate_payment_history
      credit_utilization = calculate_credit_utilization
      credit_age = calculate_credit_age
      # Reduce the penalty for brand-new users: if the user's average contract
      # age is less than 1 year, scale it up slightly so they aren't overly
      # penalized for being new to the system. This increases fairness for new
      # customers while keeping the contribution stable for experienced users.
      credit_age = adjust_credit_age_for_new_user(credit_age)
      total_accounts = calculate_total_accounts

      # Combine the factors to calculate the credit score
      credit_score = ((payment_history * 0.40) + (credit_utilization * 0.20) +
                     (credit_age * 0.21) + (total_accounts * 0.19)).round

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

      return 0 if total_credit.zero?

      ((total_balance / total_credit) * 100).round(2) # Percentage
    end

    def calculate_credit_age
      contracts = @user.contracts
      return 0 if contracts.empty?

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
