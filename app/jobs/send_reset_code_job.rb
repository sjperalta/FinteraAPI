# frozen_string_literal: true

# app/jobs/send_reset_code_job.rb
class SendResetCodeJob < ApplicationJob
  queue_as :default

  def perform(user_id, code)
    Rails.logger.info "[SendResetCodeJob] Sending reset code for user_id=#{user_id}"
    user = User.find_by(id: user_id)
    unless user
      Rails.logger.warn "[SendResetCodeJob] User not found id=#{user_id}"
      return
    end

    Users::SendResetCodeService.new(user, code).call
    Rails.logger.info "[SendResetCodeJob] Reset code sent for user_id=#{user_id}"
  end
end
