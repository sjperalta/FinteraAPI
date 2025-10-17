# frozen_string_literal: true

# Concern for invalidating lots index cache
# Include this in any service or controller that modifies lots
module LotCacheInvalidation
  extend ActiveSupport::Concern

  private

  # Invalidates lots index cache for the project containing the lot
  # This ensures all users see the updated lot list for the project
  # @param lot [Lot] the lot that was modified
  def invalidate_lot_cache(lot)
    # Clear cache for all lots in this project (project-based caching)
    Rails.cache.delete_matched("lots_index_#{lot.project_id}_*")

    # If you want more granular user-based invalidation in the future:
    # Clear cache for all admin users (they can see all lots)
    # User.where(role: 'admin').pluck(:id).each do |admin_id|
    #   Rails.cache.delete_matched("lots/index/#{admin_id}/#{lot.project_id}/*")
    # end
  end

  # Less efficient but simpler: Clear all lots cache across all projects
  # Use this if you need to invalidate everything (rare)
  def invalidate_all_lots_cache
    Rails.cache.delete_matched('lots_index_*')
  end
end
