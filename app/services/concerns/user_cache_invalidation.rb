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

    # Use versioned keys to avoid expensive wildcard cache scans.
    # Bump the admin-wide users index version so all admin cache entries
    # become stale. This replaces iterating all admin ids and calling
    # delete_matched for each one.
    increment_users_admin_version

    # Bump the modified user's personal users-index version so any cached
    # views scoped to that user become stale.
    increment_users_index_version(user.id)
  end

  # Invalidates users index cache for all users
  # Use when you need to clear all user list views (e.g., bulk operations)
  def invalidate_users_cache
    # Fallback for full invalidation; avoid using this frequently as it may
    # trigger expensive scans depending on the cache store.
    Rails.cache.delete_matched('users/index/*')
  end

  # Alias for consistency with other cache invalidation patterns
  def invalidate_all_users_cache
    invalidate_users_cache
  end

  # Versioning helpers -------------------------------------------------

  def users_index_version_key(user_id)
    "users_index_version:#{user_id}"
  end

  def users_index_version(user_id)
    (Rails.cache.read(users_index_version_key(user_id)) || 1).to_i
  end

  def increment_users_index_version(user_id)
    key = users_index_version_key(user_id)
    if Rails.cache.respond_to?(:increment)
      Rails.cache.increment(key, 1, initial: 2)
    else
      current = (Rails.cache.read(key) || 1).to_i
      Rails.cache.write(key, current + 1)
    end
  end

  # Admin-wide version used by all admin users' index cache entries so that
  # a single bump invalidates admin views without scanning the cache store.
  def users_admin_version_key
    'users_index_admin_version'
  end

  def users_admin_version
    (Rails.cache.read(users_admin_version_key) || 1).to_i
  end

  def increment_users_admin_version
    key = users_admin_version_key
    if Rails.cache.respond_to?(:increment)
      Rails.cache.increment(key, 1, initial: 2)
    else
      current = (Rails.cache.read(key) || 1).to_i
      Rails.cache.write(key, current + 1)
    end
  end
end
