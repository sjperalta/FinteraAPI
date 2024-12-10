# app/controllers/api/v1/users_controller.rb

class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!, only: [:create, :update, :recover_password, :resend_confirmation, :toggle_status]
  load_and_authorize_resource

  # GET /api/v1/users (lista todos los usuarios)
  def index
    users = User.all

    # Apply role if present
    if params[:role].present?
      users = users.where(role: params[:role].downcase)
    end

    # Aplicar filtros si están presentes en los parámetros
    if params[:search_term].present?
      term = "%#{params[:search_term].downcase}%"
      users = users.where('email LIKE ? OR full_name LIKE ? OR phone LIKE ?', term, term, term)
    end

    render json: users.as_json(only: [:id, :full_name, :email, :phone, :role, :status]), status: :ok
  end

  # GET /api/v1/users/:id (muestra un usuario en particular)
  def show
    user = User.find(params[:id])
    render json: user.as_json(only: [:id, :full_name, :email, :phone, :role, :status]), status: :ok
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

  # PUT /api/v1/users/:id
  # Update an existing user's details
  def update
    if @user.update(user_params)
      render json: { message: 'User updated successfully' }, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
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
