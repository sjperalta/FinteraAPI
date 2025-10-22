# frozen_string_literal: true

# app/services/users/resend_confirmation_service.rb
module Users
  # Service to resend confirmation instructions to a user
  class ResendConfirmationService
    def initialize(user_id:)
      @user_id = user_id
    end

    def call
      user = User.find(@user_id)

      if user.confirmed?
        { success: false, message: 'User is already confirmed.' }
      elsif user.can_resend_confirmation_email?
        user.send_confirmation_instructions
        { success: true, message: 'Confirmation email sent successfully.' }
      else
        { success: false, message: 'User cannot be confirmed at this time.' }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, message: 'User not found.' }
    end
  end
end
