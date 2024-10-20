# app/controllers/api/v1/users_controller.rb

class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!, only: [:create]
  before_action :verify_seller_or_admin, only: [:create]

  # POST /api/v1/users (solo vendedores o administradores pueden crear usuarios)
  def create
    service = Users::CreateUserService.new(
      name: user_params[:name],
      email: user_params[:email],
      password: user_params[:password],
      password_confirmation: user_params[:password_confirmation],
      role: user_params[:role] # Verificar si se quiere crear un vendedor o un admin
    )

    result = service.call

    if result[:success]
      render json: { message: 'User successfully created. Confirmation email sent.' }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/password (recuperar contraseña)
  def recover_password
    @user = User.find_by(email: params[:email])
    if @user.present?
      @user.send_reset_password_instructions
      render json: { message: 'Password recovery instructions sent.' }, status: :ok
    else
      render json: { error: 'Email not found' }, status: :not_found
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  def verify_seller_or_admin
    unless current_user.seller? || current_user.admin?
      render json: { error: 'Only sellers or admins can create users' }, status: :forbidden
    end
  end
end
