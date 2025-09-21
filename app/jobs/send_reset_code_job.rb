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

    begin
      Users::SendResetCodeService.new(user, code).call
      Rails.logger.info "[SendResetCodeJob] Reset code sent for user_id=#{user_id}"
    rescue StandardError => e
      Rails.logger.error "[SendResetCodeJob] Error sending reset code for user_id=#{user_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
