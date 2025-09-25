# frozen_string_literal: true

# app/controllers/api/v1/users_controller.rb

module Api
  module V1
    # Controller for managing users
    class UsersController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      before_action :authenticate_user!, except: [:recover_password]
      skip_before_action :authenticate_user!, only: %i[
        send_recovery_code
        verify_recovery_code
        update_password_with_code
      ]
      load_and_authorize_resource
      skip_load_resource only: [:restore]
      skip_authorize_resource only: [:restore]
      before_action :set_user, only: %i[show update contracts payments summary upload_receipt restore]
      before_action :set_payment, only: [:upload_receipt]

      SEARCHABLE_FIELDS = %w[email full_name phone identity rtn role].freeze

      # GET /api/v1/users
      def index
        # Authorization checks (admin or seller only)
        unless current_user&.admin? || current_user&.seller?
          return render json: { error: 'Not authorized' }, status: :forbidden
        end

        # Base scope
        users = User.all

        # Apply your standard filtering approach
        users = apply_filters(users, params, SEARCHABLE_FIELDS)

        # Pagy integration
        @pagy, @users = pagy(
          users,
          items: (params[:per_page] || 20).to_i,
          page: params[:page]
        )

        render json: {
          users: @users.as_json(only: fields_for_render),
          pagination: pagy_metadata(@pagy)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue StandardError
        render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
      end

      # GET /api/v1/user/:id (muestra un usuario en particular)
      def show
        render json: @user.as_json(only: fields_for_render), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      # POST /api/v1/users
      # Example for creating users (admin or seller?).
      def create
        service = Users::CreateUserService.new(user_params:, creator_id: current_user&.id)
        result = service.call
        if result[:success]
          render json: { success: true, message: 'User created. Confirmation sent.' }, status: :created
        else
          render json: { success: false, errors: result[:errors] }, status: :unprocessable_content
        end
      end

      # PUT /api/v1/users/:id
      def update
        # Possibly verify admin or self?
        if @user.update(user_params.except(:id))
          render json: { success: true, message: 'User updated successfully' }, status: :ok
        else
          render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        if current_user.admin? # Ensure only admin can delete users
          if @user.soft_delete
            render json: { message: 'User soft deleted successfully' }, status: :ok
          else
            render json: { error: 'Failed to soft delete user' }, status: :unprocessable_content
          end
        else
          render json: { error: 'Not authorized' }, status: :forbidden
        end
      end

      # POST /api/v1/users/:id/restore
      def restore
        if current_user.admin? # Ensure only admin can restore users
          if @user.restore
            render json: { message: 'User restored successfully' }, status: :ok
          else
            render json: { error: 'Failed to restore user' }, status: :unprocessable_content
          end
        else
          render json: { error: 'Not authorized' }, status: :forbidden
        end
      end

      # PUT /api/v1/users/:id/toggle_status
      def toggle_status
        if current_user&.admin?
          @user = User.find(params[:id])
          new_status = @user.active? ? 'inactive' : 'active'
          if @user.update(status: new_status)
            message = new_status == 'active' ? 'User activated' : 'User deactivated'
            render json: { success: true, message: }, status: :ok
          else
            render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_content
          end
        else
          render json: { error: 'Not authorized' }, status: :forbidden
        end
      end

      # POST /api/v1/users/:id/resend_confirmation
      def resend_confirmation
        service = Users::ResendConfirmationService.new(user_id: params[:id])
        result = service.call
        if result[:success]
          render json: { message: result[:message] }, status: :ok
        else
          render json: { message: result[:message] }, status: :unprocessable_content
        end
      end

      # POST /api/v1/user/password (recuperar contraseña)
      def recover_password
        @user = User.find_by(email: params[:email])
        if @user.present?
          @user.send_reset_password_instructions
          render json: { message: 'Password recovery instructions sent.' }, status: :ok
        else
          render json: { error: 'Email not found' }, status: :not_found
        end
      end

      # PATCH /api/v1/users/change_password
      def change_password
        # Load the target user from params; user_for_password_change will render errors if missing
        user = user_for_password_change
        return unless user

        # Allow users to change their own password or admins to change any user's password
        if @user.id == password_change_params[:userId].to_i || @user.admin?
          handle_admin_password_change(user)
        else
          render json: { errors: ['Change user password is not allowed'] }, status: :unauthorized
        end
      end

      # POST /api/v1/users/send_recovery_code
      def send_recovery_code
        user = User.find_by(email: params[:email]&.downcase)
        return render json: { success: false, error: 'No se encontro Email' }, status: :not_found unless user

        # remember this recovery code is 5 digits
        code = if ENV['RAILS_ENV'] == 'development'
                 99_999
               else
                 rand(10_000..99_999).to_s
               end
        user.update!(
          recovery_code: code,
          recovery_code_sent_at: Time.now
        )

        # Enqueue job to send the code
        SendResetCodeJob.perform_later(user.id, code)

        render json: { success: true, message: 'Verification code sent to your email.' }, status: :ok
      end

      # POST /api/v1/users/verify_recovery_code
      def verify_recovery_code
        return render json: { error: 'Code is required' }, status: :bad_request if params[:code].blank?

        user = User.find_by(email: params[:email]&.downcase)
        return render json: { success: false, error: 'Email not found' }, status: :not_found if user.blank?

        # e.g., code is valid for 15 minutes
        if user.recovery_code == params[:code] && user.recovery_code_sent_at >= 15.minutes.ago
          render json: { success: true, message: 'Code verified successfully.' }, status: :ok
        else
          render json: { success: false, error: 'Invalid or expired code.' }, status: :unprocessable_content
        end
      end

      # POST /api/v1/users/update_password_with_code
      def update_password_with_code
        unless valid_password?(params[:new_password])
          return render json: { error: 'Contraseña muy debil, deberia estar compuesta de una minuscula, una Mayuscula, y numeros' },
                        status: :unprocessable_content
        end

        user = User.find_by(email: params[:email]&.downcase)
        return render json: { success: false, error: 'Email not found' }, status: :not_found if user.blank?

        # Check the code
        if user.recovery_code == params[:code] && user.recovery_code_sent_at >= 15.minutes.ago
          # Password
          if params[:new_password] == params[:new_password_confirmation]
            user.update!(
              password: params[:new_password],
              password_confirmation: params[:new_password_confirmation],
              # Clear the code so it can’t be reused
              recovery_code: nil,
              recovery_code_sent_at: nil
            )
            render json: { success: true, message: 'Password updated successfully.' }, status: :ok
          else
            render json: { success: false, error: 'Password confirmation mismatch.' }, status: :unprocessable_content
          end
        else
          render json: { success: false, error: 'Invalid or expired code.' }, status: :unprocessable_content
        end
      end

      # GET /api/v1/user/:id/contracts
      def contracts
        contracts = @user.contracts
        render json: contracts.as_json(only: %i[id name status financing_type created_at]), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      # GET /api/v1/user/:id/payments
      def payments
        payments = Payment.joins(:contract).where(
          contracts: { applicant_user_id: @user.id, status: Contract::STATUS_APPROVED }, status: %w[pending submitted]
        )

        # Include contract details in the JSON response.
        # Adjust the :only fields for contract according to the attributes you want to return.
        render json: payments.as_json(
          only: %i[id description amount status due_date contract_id created_at approved_at payment_date
                   interest_amount],
          include: {
            contract: {
              only: %i[id name status currency created_at]
            }
          }
        ), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      # GET /api/v1/user/:id/summary
      def summary
        result = Users::UserSummaryService.new(@user).call
        render json: result, status: :ok
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      private

      def set_user
        @user = User.with_discarded.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def set_payment
        @payment = Payment.find(params[:paymentId])
      end

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

      def handle_admin_password_change(user)
        if user.update(password: new_pass, password_confirmation: new_pass)
          render json: { success: true, message: 'Password updated by admin' }, status: :ok
        else
          render json: { success: false, errors: user.errors.full_messages }, status: :unprocessable_content
        end
      end

      def new_pass
        params[:password_change][:new_password]
      end

      def password_change_params
        params.require(:password_change).permit(:userId, :new_password, :new_password_confirmation)
      end

      def valid_password?(password)
        return false if password.nil?

        password.length >= 8 &&
          password.match?(/[A-Z]/) &&
          password.match?(/[a-z]/) &&
          password.match?(/\d/)
      end

      def fields_for_render
        %i[id full_name identity rtn email address phone role status created_by created_at note]
      end

      def user_params
        params.require(:user).permit(
          :identity,
          :rtn,
          :address,
          :email,
          :password,
          :password_confirmation,
          :role,
          :full_name,
          :phone,
          :note,
          :created_at,
          :created_by,
          :status
        )
      end
    end
  end
end
