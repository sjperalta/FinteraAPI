# app/controllers/api/v1/users_controller.rb
  class Api::V1::UserController < ApplicationController
    before_action :authenticate_user!, only: [:update, :change_password, :contracts, :payments, :summary]
    load_and_authorize_resource
    before_action :set_user, only: [:show, :update, :contracts, :payments, :upload_receipt, :summary]
    before_action :set_payment, only: [:upload_receipt]

    # GET /api/v1/user/:id (muestra un usuario en particular)
    def show
      render json: @user.as_json(only: [:id, :full_name, :identity, :rtn, :email, :phone, :role, :status]), status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    end

    # PUT /api/v1/user/:id
    # Update an existing user's details
    def update
      if @user.update(user_params)
        render json: { message: 'User updated successfully' }, status: :ok
      else
        render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
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

    # PATCH /api/v1/user/change_password
    def change_password
      if @user.id == password_change_params[:userId]
        loged_user_change_password(@user)
      elsif @user.admin?
        user = User.find(password_change_params[:userId])
        admin_user_change_password(user) # admin can override password
      else
        render json: { errors: ["Change user password is not allowed"] }, status: :unauthorized
      end
    end

    # GET /api/v1/user/:id/contracts
    def contracts
      contracts = @user.contracts
      render json: contracts.as_json(only: [:id, :name, :status, :financing_type, :created_at]), status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    end

    # GET /api/v1/user/:id/payments
    def payments
      payments = Payment.joins(:contract).where(contracts: { applicant_user_id: @user.id, status: Contract::STATUS_APPROVED }, status: ['pending', 'submitted'])

      # Include contract details in the JSON response.
      # Adjust the :only fields for contract according to the attributes you want to return.
      render json: payments.as_json(
        only: [:id, :description, :amount, :status, :due_date, :contract_id, :created_at, :approved_at, :payment_date, :interest_amount],
        include: {
          contract: {
            only: [:id, :name, :status, :currency, :created_at]
          }
        }
      ), status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    end

    # POST /api/v1/user/:id/upload_receipt
    def upload_receipt
      if params[:receipt].present?
        service = Payments::UploadReceiptService.new(payment: @payment, receipt: params[:receipt], user: @user)

        if service.call
          render json: { message: 'Comprobante subido exitosamente, esperando aprobación' }, status: :ok
        else
          render json: { error: 'No se pudo subir el comprobante' }, status: :unprocessable_entity
        end
      else
        render json: { error: 'No se proporcionó un archivo para el comprobante' }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Payment not found' }, status: :not_found
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
      @user = User.find(params[:id])
    end

    def set_payment
      @payment = Payment.find(params[:paymentId])
    end

    def loged_user_change_password(user)
      if user.valid_password?(password_change_params[:old_password])
        if user.update(password: password_change_params[:new_password], password_confirmation: password_change_params[:new_password])
          render json: { message: "Contraseña actualizada exitosamente." }, status: :ok
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { errors: ["La contraseña anterior es incorrecta."] }, status: :unauthorized
      end
    end

    def admin_user_change_password(user)
      if user.update(password: password_change_params[:new_password], password_confirmation: password_change_params[:new_password])
        render json: { message: "Contraseña actualizada exitosamente." }, status: :ok
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def password_change_params
      params.require(:password_change).permit(:userId, :old_password, :new_password)
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
        :phone)
    end
  end
