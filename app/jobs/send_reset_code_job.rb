# app/jobs/send_reset_code_job.rb
class SendResetCodeJob < ApplicationJob
  queue_as :default

  def perform(user_id, code)
    user = User.find(user_id)
    Users::SendResetCodeService.new(user, code).call
  end
end
