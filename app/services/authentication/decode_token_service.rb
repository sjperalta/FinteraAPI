# app/services/authentication/decode_token_service.rb

module Authentication
  class DecodeTokenService
    def initialize(token:)
      @token = token
    end

    def call
      decoded_token = JsonWebToken.decode(@token)
      if decoded_token
        user = User.find_by(id: decoded_token[:user_id])
        { success: true, user: user }
      else
        { success: false, errors: ['Invalid token'] }
      end
    end
  end
end
