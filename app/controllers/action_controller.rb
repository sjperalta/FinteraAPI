# app/controllers/action_controller.rb

class ActionController < ActionController::Base
  before_action :authenticate_user!

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

    decoded_token = decode_token(token)
    if decoded_token && decoded_token[:exp] > Time.now.to_i
      @current_user = User.find(decoded_token[:user_id])
    else
      render json: { error: 'Token expired or invalid' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def decode_token(token)
    JWT.decode(token, ENV['SECRET_KEY_BASE'])[0].symbolize_keys
  rescue JWT::DecodeError
    nil
  end
end
