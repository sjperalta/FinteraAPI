module Users
  class CreateUserService
    def initialize(user_params:)
      @user_params = user_params
    end

    def notify_admin(user)
      users = User.where(role: 'admin')
      users.each do |admin|
        Notification.create(
          user: admin,
          title: "Nuevo Usuario.",
          message: "Se han create un nuevo usuario #{user.full_name}",
          notification_type: "create_new_user"
        )
      end
    end

    def welcome_message(user)
      Notification.create(
          user: user,
          title: "Bienvenido!",
          message: "Hola #{user.full_name}, gracias por ser parte de Fintera.",
          notification_type: "onboard_user"
        )
    end

    def call
      user = User.new(@user_params)
      notify_admin(user)
      welcome_message(user)

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
