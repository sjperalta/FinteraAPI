# app/services/notifications/overdue_payment_email_service.rb

module Notifications
  class OverduePaymentEmailService
    def initialize(user, payments)
      @user = user
      @payments = payments
    end

    def call
      send_overdue_email
    end

    private

    def send_overdue_email
      UserMailer.with(user: @user, payments: @payments).overdue_payment_email.deliver_now
    end
  end
end
