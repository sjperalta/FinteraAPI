# frozen_string_literal: true

# Concern for invalidating payment-related caches
module PaymentCacheInvalidation
  extend ActiveSupport::Concern

  # Invalidate payment index cache for the user who owns the contract
  # and for all admin users who can see all payments
  # params:
  #   payment: The payment object whose cache needs to be invalidated
  def invalidate_payment_cache(payment)
    # Clear cache for the contract owner (the user who made the payment)
    user_id = payment.contract.applicant_user_id
    Rails.cache.delete_matched("payments/index/#{user_id}/*")

    # Clear cache for all admin users (they can see all payments)
    # Use role column, not admin boolean
    User.where(role: 'admin').pluck(:id).each do |admin_id|
      Rails.cache.delete_matched("payments/index/#{admin_id}/*")
    end
  end

  # Invalidate all payment index cache (use sparingly)
  # This is a fallback for when we don't have a specific payment context
  def invalidate_all_payments_cache
    Rails.cache.delete_matched('payments/index/*')
  end
end
