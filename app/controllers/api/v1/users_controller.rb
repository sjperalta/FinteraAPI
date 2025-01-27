# app/controllers/api/v1/users_controller.rb

module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!, except: [:recover_password]
      load_and_authorize_resource

      # GET /api/v1/users
      def index
        # Example: only admin or seller can list users
        unless current_user&.admin? || current_user&.seller?
          return render json: { error: 'Not authorized' }, status: :forbidden
        end

        # Base scope
        users = User.all

        # Filter by role if provided
        if params[:role].present?
          users = users.where(role: params[:role].downcase)
        end

        # Apply search term if provided
        if params[:search_term].present?
          term = "%#{params[:search_term].downcase}%"
          users = users.where(
            "LOWER(email) LIKE ? OR LOWER(full_name) LIKE ? OR phone LIKE ? OR identity LIKE ? OR rtn LIKE ?",
            term, term, term, term, term
          )
        end

        # Pagy integration
        # items: how many per page, defaults to 20 if not specified
        # page: which page number to fetch
        @pagy, @users = pagy(
          users,
          items: (params[:per_page] || 20),
          page: params[:page]
        )

        # Include pagination metadata in the JSON
        pagination_metadata = pagy_metadata(@pagy)

        render json: {
          users: @users.as_json(only: fields_for_render),
          pagination: pagination_metadata
        }, status: :ok
      end

      # POST /api/v1/users
      # Example for creating users (admin or seller?).
      def create
        service = Users::CreateUserService.new(user_params: user_params)
        result = service.call
        if result[:success]
          render json: { success: true, message: 'User created. Confirmation sent.' }, status: :created
        else
          render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/users/:id
      def update
        # Possibly verify admin or self?
        if @user.update(user_params.except(:id))
          render json: { success: true, message: 'User updated successfully' }, status: :ok
        else
          render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/users/:id/toggle_status
      def toggle_status
        if current_user&.admin?
          @user = User.find(params[:id])
          new_status = @user.active? ? 'inactive' : 'active'
          if @user.update(status: new_status)
            message = new_status == 'active' ? 'User activated' : 'User deactivated'
            render json: { success: true, message: message }, status: :ok
          else
            render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: 'Not authorized' }, status: :forbidden
        end
      end

      # POST /api/v1/user/:id/resend_confirmation
      def resend_confirmation
        service = Users::ResendConfirmationService.new(user_id: params[:id])
        result = service.call
        if result[:success]
          render json: { message: result[:message] }, status: :ok
        else
          render json: { message: result[:message] }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/users/password
      def recover_password
        user = User.find_by(email: params[:email])
        if user
          user.send_reset_password_instructions
          render json: { success: true, message: 'Password recovery instructions sent' }, status: :ok
        else
          render json: { success: false, error: 'Email not found' }, status: :not_found
        end
      end

      # PATCH /api/v1/users/change_password
      def change_password
        # Combine logic into one function or keep separate if you prefer
        user_to_change = user_for_password_change
        return unless user_to_change

        if user_can_change_own_password?(user_to_change)
          handle_own_password_change(user_to_change)
        elsif current_user.admin?
          handle_admin_password_change(user_to_change)
        else
          render json: { success: false, errors: ['Not authorized'] }, status: :unauthorized
        end
      end

      private

      def user_for_password_change
        if params[:password_change].blank?
          render json: { success: false, errors: ['No password_change params provided'] }, status: :bad_request
          return nil
        end
        userId = params[:password_change][:userId]
        User.find(userId)
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, errors: ['User not found'] }, status: :not_found
        nil
      end

      def user_can_change_own_password?(user)
        user.id == current_user.id
      end

      def handle_own_password_change(user)
        if user.valid_password?(params[:password_change][:old_password])
          if user.update(password: new_pass, password_confirmation: new_pass)
            render json: { success: true, message: 'Password updated successfully' }, status: :ok
          else
            render json: { success: false, errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Incorrect old password'] }, status: :unauthorized
        end
      end

      def handle_admin_password_change(user)
        if user.update(password: new_pass, password_confirmation: new_pass)
          render json: { success: true, message: 'Password updated by admin' }, status: :ok
        else
          render json: { success: false, errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def new_pass
        params[:password_change][:new_password]
      end

      def fields_for_render
        [:id, :full_name, :identity, :rtn, :email, :phone, :role, :status]
      end

      def user_params
        params.require(:user).permit(
          :identity,
          :rtn,
          :email,
          :password,
          :password_confirmation,
          :role,
          :full_name,
          :phone
        )
      end
    end
  end
end
