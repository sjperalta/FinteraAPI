module Users
  class CreateUserService
    def initialize(user_params:)
      @user_params = user_params
    end

    def call
      user = User.new(@user_params)

      if user.save
        # Si estás utilizando confirmable en Devise, se envía el email de confirmación
        user.send_confirmation_instructions if user.respond_to?(:send_confirmation_instructions)
        { success: true, user: user }
      else
        { success: false, errors: user.errors.full_messages }
      end
    rescue => e
      Rails.logger.error("Error creating user: #{e.message}")
      { success: false, errors: [e.message] }
    end
  end
end
