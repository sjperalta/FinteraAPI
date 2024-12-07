# app/controllers/api/v1/users_controller.rb

class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!, only: [:create, :recover_password, :resend_confirmation, :toggle_status]
  load_and_authorize_resource

  # GET /api/v1/users (lista todos los usuarios)
  def index
    users = User.all

    # Aplicar filtros si están presentes en los parámetros
    users = users.where('email LIKE ?', "%#{params[:email]}%") if params[:email].present?
    users = users.where('full_name LIKE ?', "%#{params[:full_name]}%") if params[:full_name].present?
    users = users.where(role: params[:role]) if params[:role].present?

    render json: users, status: :ok
  end

  # GET /api/v1/users/:id (muestra un usuario en particular)
  def show
    user = User.find(params[:id])
    render json: user, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  # POST /api/v1/users (solo vendedores o administradores pueden crear usuarios)
  def create
    service = Users::CreateUserService.new(user_params: user_params)
    result = service.call

    if result[:success]
      render json: { message: 'User successfully created. Confirmation email sent.' }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/:id/resend_confirmation
  def resend_confirmation
    service = Users::ResendConfirmationService.new(user_id: params[:id])
    result = service.call

    if result[:success]
      render json: { message: result[:message] }, status: :ok
    else
      render json: { message: result[:message] }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/users/:id/toggle_status
  def toggle_status
    user = User.find(params[:id])
    user.update(status: user.active? ? 'inactive' : 'active')
    message = user.active? ? 'User activated successfully' : 'User deactivated successfully'
    render json: { message: message }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
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
    params.require(:user).permit(:id, :name, :email, :password, :password_confirmation, :role, :full_name, :phone)
  end
end
