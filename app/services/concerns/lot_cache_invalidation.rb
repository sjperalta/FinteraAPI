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
    # Increment project-specific version so cached keys become stale without
    # performing an expensive wildcard delete on the cache store.
    increment_lots_index_version(lot.project_id)

    # If you want more granular user-based invalidation in the future:
    # Clear cache for all admin users (they can see all lots)
    # User.where(role: 'admin').pluck(:id).each do |admin_id|
    #   Rails.cache.delete_matched("lots/index/#{admin_id}/#{lot.project_id}/*")
    # end
  end

  # Less efficient but simpler: Clear all lots cache across all projects
  # Use this if you need to invalidate everything (rare)
  def invalidate_all_lots_cache
    # Fallback for rare cases: clear everything. Prefer per-project versioning
    # where possible to avoid expensive delete_matched operations.
    Rails.cache.delete_matched('lots_index_*')
  end

  # Helper: returns the cache key used to store the per-project lots index version
  def lots_index_version_key(project_id)
    "lots_index_version:#{project_id}"
  end

  # Returns the current version number for project lots index (default 1)
  def lots_index_version(project_id)
    (Rails.cache.read(lots_index_version_key(project_id)) || 1).to_i
  end

  # Increment the per-project version counter. Uses `increment` when the
  # cache store supports it to avoid race conditions; otherwise reads and
  # writes a new incremented value.
  def increment_lots_index_version(project_id)
    key = lots_index_version_key(project_id)
    if Rails.cache.respond_to?(:increment)
      Rails.cache.increment(key, 1, initial: 2) # initial:2 because default read returns 1
    else
      current = (Rails.cache.read(key) || 1).to_i
      Rails.cache.write(key, current + 1)
    end
  end
end
