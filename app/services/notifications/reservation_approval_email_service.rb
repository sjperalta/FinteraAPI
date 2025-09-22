# frozen_string_literal: true

# app/services/notifications/reservation_approval_email_service.rb
module Notifications
  class ReservationApprovalEmailService
    def initialize(contract)
      @contract = contract
      @user = @contract&.applicant_user
    end

    def call
      return unless @user

      UserMailer.with(user: @user, contract: @contract).reservation_approved.deliver_now
    end
  end
end
