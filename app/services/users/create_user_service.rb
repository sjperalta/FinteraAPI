# app/services/users/create_user_service.rb

module Users
  class CreateUserService
    def initialize(name:, email:, password:, password_confirmation:, role:)
      @name = name
      @role = role
      @user_params = {
        name: name,
        email: email,
        password: password,
        password_confirmation: password_confirmation
      }
    end

    def call
      user = User.new(@user_params)
      user.role = @role

      if user.save
        # Enviar el correo de confirmación si Devise está configurado con confirmable
        user.send_confirmation_instructions
        return { success: true, user: user }
      else
        return { success: false, errors: user.errors.full_messages }
      end
    end
  end
end
