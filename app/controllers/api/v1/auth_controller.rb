# app/controllers/api/v1/authentication_controller.rb

class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login]

  # POST /api/v1/auth/login
  def login
    service = Authentication::AuthenticateUserService.new(email: params[:email], password: params[:password])
    result = service.call

    if result[:success]
      render json: { token: result[:token], user: result[:user] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: 401
    end
  end
end
