# frozen_string_literal: true

# app/controllers/api/v1/authentication_controller.rb

module Api
  module V1
    # Controller for user authentication (login, logout, token refresh)
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[login refresh]

      # POST /api/v1/auth/login
      def login
        service = Authentication::AuthenticateUserService.new(email: params[:email], password: params[:password])
        result = service.call

        if result[:success]
          render json: { token: result[:token], refresh_token: result[:refresh_token], user: result[:user] },
                 status: :ok
        else
          render json: { errors: result[:errors] }, status: 401
        end
      end

      # POST /api/v1/auth/logout
      def logout
        refresh_token = params[:refresh_token]

        return render json: { error: 'Invalid or missing token' }, status: 401 if refresh_token.blank?

        # Find refresh token
        token = RefreshToken.find_by(token: refresh_token)

        if token
          token.destroy
          render json: { message: 'Logged out successfully' }, status: :ok
        else
          render json: { error: 'Invalid or missing token' }, status: 401
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        service = Authentication::RefreshTokenService.new(refresh_token: params[:refresh_token])
        result = service.call

        if result[:success]
          render json: result.except(:success), status: :ok
        else
          render json: { errors: result[:errors] }, status: :unauthorized
        end
      end
    end
  end
end
