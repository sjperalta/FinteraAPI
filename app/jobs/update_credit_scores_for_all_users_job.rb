# frozen_string_literal: true

# app/jobs/update_credit_scores_for_all_users_job.rb
# Job to update credit scores for all users with role 'user'
class UpdateCreditScoresForAllUsersJob < ApplicationJob
  queue_as :default

  def perform
    User.regular_users.kept.find_each(&:update_credit_score)
  end
end
