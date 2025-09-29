# frozen_string_literal: true

# app/jobs/update_credit_scores_job.rb
# Job to update credit scores for specific users with role 'user'
class UpdateCreditScoresJob < ApplicationJob
  queue_as :default

  def perform(user_ids)
    User.where(id: user_ids).find_each do |user|
      user.update_credit_score
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn("User with ID \\#{user.id} not found. Skipping credit score update.")
    end
  end
end
