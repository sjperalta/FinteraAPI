# frozen_string_literal: true

# Concern for invalidating contracts index cache
# Include this in any service that modifies contracts or their associated payments
module ContractCacheInvalidation
  extend ActiveSupport::Concern

  private

  # Invalidates contracts index cache only for users who can see the modified contract
  # This is more surgical than deleting all cache entries
  # @param contract [Contract] the contract that was modified
  def invalidate_contract_cache(contract)
    # Clear cache for the contract creator (they can see their own contracts)
    Rails.cache.delete_matched("contracts/index/#{contract.creator_id}/*") if contract.creator_id

    # Clear cache for all admin users (they can see all contracts)
    User.where(role: 'admin').pluck(:id).each do |admin_id|
      Rails.cache.delete_matched("contracts/index/#{admin_id}/*")
    end
  end

  # Less efficient but simpler: Clear all contracts cache
  # Use this if the targeted approach causes issues
  def invalidate_all_contracts_cache
    Rails.cache.delete_matched('contracts/index/*')
  end
end
