# frozen_string_literal: true

# app/jobs/update_credit_scores_job.rb
# Job to update credit scores for specific users with role 'user'
class UpdateCreditScoresJob < ApplicationJob
  queue_as :default

  def perform(user_ids = nil)
    # Allow perform to be called with no args (e.g., in tests) and normalize input
    ids = Array(user_ids).compact.uniq

    if ids.empty?
      Rails.logger.info('No user IDs provided for credit score update. Exiting job.')
      return
    end

    users = User.where(id: ids).kept
    updated_count = 0
    users.find_each do |user|
      user.update_credit_score
      updated_count += 1
    end

    Rails.logger.info("Updated credit scores for #{updated_count} users, Ids: #{ids.join(', ')}")
  rescue StandardError => e
    Rails.logger.error("[UpdateCreditScoresJob] error updating credit scores: #{e.message}")
    Rails.logger.error e.backtrace.join("\n")
  end
end
