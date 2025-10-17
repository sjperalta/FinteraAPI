# frozen_string_literal: true

# Concern for invalidating users index cache
# Include this in any service or controller that modifies users
#
# Cache invalidation strategy:
# - Users index cache is scoped by current_user.id to respect permissions
# - When a user is modified, we invalidate:
#   1. Cache for all admin users (they see all users)
#   2. Cache for the affected user if they view the users list
module UserCacheInvalidation
  extend ActiveSupport::Concern

  private

  # Invalidates cache for a specific user modification
  # Clears cache for all users who might see this user in their list
  # @param user [User] the user that was modified
  def invalidate_user_cache(user)
    return unless user

    # Clear cache for all admin users (they see all users in the list)
    User.where(role: 'admin').pluck(:id).each do |admin_id|
      Rails.cache.delete_matched("users/index/#{admin_id}/*")
    end

    # If the user views their own list (unlikely but possible), invalidate their cache too
    # In practice, most users won't request the users list, but we'll be thorough
    Rails.cache.delete_matched("users/index/#{user.id}/*")
  end

  # Invalidates users index cache for all users
  # Use when you need to clear all user list views (e.g., bulk operations)
  def invalidate_users_cache
    Rails.cache.delete_matched('users/index/*')
  end

  # Alias for consistency with other cache invalidation patterns
  def invalidate_all_users_cache
    invalidate_users_cache
  end
end
