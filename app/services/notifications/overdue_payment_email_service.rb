# frozen_string_literal: true

# app/services/notifications/overdue_payment_email_service.rb

module Notifications
  # Service to send overdue payment email notifications to users.
  class OverduePaymentEmailService
    def initialize(user, payments)
      @user = user
      @payments = payments
    end

    def call
      # check if the user is active before sending email
      return unless @user.active?

      send_overdue_email
    end

    private

    def send_overdue_email
      UserMailer.with(user: @user, payments: @payments).overdue_payment_email.deliver_now
    end
  end
end
