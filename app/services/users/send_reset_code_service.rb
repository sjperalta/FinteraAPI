# frozen_string_literal: true

# app/services/notifications/send_reset_code_service.rb
module Users
  class SendResetCodeService
    def initialize(user, code)
      @user = user
      @code = code
    end

    def call
      send_reset_code_email
    end

    private

    def send_reset_code_email
      # Suppose we have a mailer method `reset_code_email` in `UserMailer`
      UserMailer.with(user: @user, code: @code).reset_code_email.deliver_now
    end
  end
end
