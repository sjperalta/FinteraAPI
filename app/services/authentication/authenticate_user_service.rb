# app/services/authentication/authenticate_user_service.rb

module Authentication
  class AuthenticateUserService
    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      user = User.find_by(email: @email)

      if user&.valid_password?(@password)
        token = JsonWebToken.encode(user_id: user.id)
        { success: true, token: token, user: user }
      else
        { success: false, errors: ['Invalid email or password'] }
      end
    end
  end
end
