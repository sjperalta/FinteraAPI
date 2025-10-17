# frozen_string_literal: true

# app/controllers/api/v1/users_controller.rb

module Api
  module V1
    # Controller for managing users
    class UsersController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      include UserCacheInvalidation

      before_action :authenticate_user!, except: [:recover_password]
      skip_before_action :authenticate_user!, only: %i[
        send_recovery_code
        verify_recovery_code
        update_password_with_code
      ]
      load_and_authorize_resource
      skip_load_and_authorize_resource only: [:index]
      skip_load_resource only: [:restore]
      skip_authorize_resource only: [:restore]
      before_action :set_user,
                    only: %i[show update contracts payments payment_history summary upload_receipt restore update_locale
                             toggle_status]
      before_action :set_payment, only: [:upload_receipt]

      SEARCHABLE_FIELDS = %w[email full_name phone identity rtn role].freeze
      SORTABLE_FIELDS = %w[full_name email phone identity rtn role created_at].freeze

      # Fields that can be searched in payment history
      PAYMENT_HISTORY_SEARCHABLE_FIELDS = %w[description contract.lot.name
                                             contract.lot.project.name].freeze
      PAYMENT_HISTORY_SORTABLE_FIELDS = %w[created_at due_date payment_date approved_at amount status
                                           payment_type].freeze

      # GET /api/v1/users
      def index
        # Base scope
        users = User.includes(:creator).all

        # Apply role-based filtering for sellers (only show users with role 'user')
        # users = users.where(role: 'user') if current_user.seller?
        # Admins see all users (no filter applied)

        # Apply role-based filtering by query parameter params[:role]
        users = users.where(role: params[:role].to_s.downcase) if params[:role].present?

        # Apply your standard filtering approach
        users = apply_filters(users, params, SEARCHABLE_FIELDS)

        # Apply sorting if sort parameters are present
        users = apply_sorting(users, params, SORTABLE_FIELDS)

        # Pagy integration
        @pagy, @users = pagy(
          users,
          items: (params[:per_page] || 20).to_i,
          page: params[:page]
        )

        # Cache the users JSON for performance. Use versioned keys to allow
        # cheap invalidation by bumping the per-user or admin version counters
        # instead of performing wildcard deletes on the cache store.
        user_version = begin
          users_index_version(current_user.id)
        rescue StandardError
          1
        end
        admin_version = begin
          users_admin_version
        rescue StandardError
          1
        end

        version_token = current_user.admin? ? "admin_v#{admin_version}" : "user_v#{user_version}"

        cache_key = ['users', 'index', current_user.id, version_token, params[:page], params[:per_page] || 20,
                     params[:search_term], params[:sort], params[:role]].join('/')
        users_json = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          @users.as_json(only: fields_for_render, include: { creator: { only: %i[id full_name] } })
        end

        render json: {
          users: users_json,
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
        authorize! :create, User
        service = Users::CreateUserService.new(user_params:, creator: current_user)
        result = service.call
        if result[:success]
          render json: { success: true, message: 'User created. Confirmation sent.' }, status: :created
        else
          render json: { success: false, errors: result[:errors] }, status: :unprocessable_content
        end
      end

      # PUT /api/v1/users/:id
      def update
        authorize! :update, User
        # Possibly verify admin or self?
        if @user.update(user_params.except(:id))
          invalidate_user_cache(@user)
          render json: { success: true, message: 'User updated successfully',
                         user: @user.as_json(only: fields_for_render) },
                 status: :ok
        else
          render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        authorize! :destroy, User
        if current_user.admin? # Ensure only admin can delete users
          if @user.soft_delete
            invalidate_user_cache(@user)
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
        authorize! :restore, User
        if current_user.admin? # Ensure only admin can restore users
          if @user.restore
            invalidate_user_cache(@user)
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
        authorize! :update, User

        # Prevent an admin from accidentally deactivating their own account
        if current_user == @user && @user.active?
          return render json: { error: 'Cannot deactivate your own account' }, status: :forbidden
        end

        new_status = @user.active? ? 'inactive' : 'active'

        if @user.update(status: new_status)
          message = new_status == 'active' ? 'User activated' : 'User deactivated'
          invalidate_user_cache(@user)
          render json: { success: true, message:, user: @user.as_json(only: fields_for_render) }, status: :ok
        else
          render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_content
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
            invalidate_user_cache(user)
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
        # Get all pending or submitted payments, ordered by due_date for approved contracts belonging to this user
        payments = Payment.includes(:contract).where(
          contracts: { applicant_user_id: @user.id, status: Contract::STATUS_APPROVED }, status: %w[pending submitted]
        )
        payments = payments.order(due_date: :asc)

        # Include contract details in the JSON response.
        # Adjust the :only fields for contract according to the attributes you want to return.
        render json: payments.as_json(
          only: %i[id description amount status due_date contract_id created_at approved_at payment_date
                   interest_amount rejection_reason],
          include: {
            contract: {
              only: %i[id balance amount status currency created_at approved_at],
              include: {
                lot: {
                  only: %i[id name address]
                }
              }
            }
          }
        ), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      # GET /api/v1/user/:id/payment_history
      def payment_history
        # Get all payments for approved contracts belonging to this user
        payments = Payment.joins(:contract)
                          .where(contracts: { applicant_user_id: @user.id,
                                              status: [Contract::STATUS_APPROVED, Contract::STATUS_CLOSED] })
                          .includes(contract: { lot: :project })

        # Total amount: sum of all payment amounts
        total = payments.sum(:amount)

        # Balance: sum of all contract balances
        balance = @user.contracts.where(status: Contract::STATUS_APPROVED).sum(:balance)

        # Overdue amount: sum of amounts for overdue payments (pending with due_date < today)
        overdue_amount = payments.where(status: %w[pending])
                                 .where('due_date < ?', Date.current)
                                 .sum('payments.amount')

        # Count paid done: count of approved payments
        count_paid_done = payments.where(status: 'paid').count

        # Apply filters
        payments = apply_payment_history_filters(payments, params)

        # Apply sorting
        payments = apply_sorting(payments, params, PAYMENT_HISTORY_SORTABLE_FIELDS)

        # Apply pagination
        @pagy, @payments = pagy(
          payments,
          items: (params[:per_page] || 20).to_i,
          page: params[:page]
        )

        # Build detailed payment history
        payment_history = @payments.map do |payment|
          {
            id: payment.id,
            description: payment.description,
            payment_type: payment.payment_type,
            amount: payment.amount,
            interest_amount: payment.interest_amount,
            total_amount: payment.amount.to_f + (payment.interest_amount || 0).to_f,
            status: payment.status,
            due_date: payment.due_date,
            payment_date: payment.payment_date,
            approved_at: payment.approved_at,
            created_at: payment.created_at,
            updated_at: payment.updated_at,
            has_receipt: payment.document.attached?,
            contract: {
              id: payment.contract.id,
              status: payment.contract.status,
              currency: payment.contract.currency,
              financing_type: payment.contract.financing_type,
              amount: payment.contract.amount,
              balance: payment.contract.balance,
              lot: {
                id: payment.contract.lot.id,
                name: payment.contract.lot.name,
                address: payment.contract.lot.address,
                project: {
                  id: payment.contract.lot.project.id,
                  name: payment.contract.lot.project.name
                }
              }
            }
          }
        end

        render json: {
          total:,
          balance:,
          overdue_amount:,
          payment_count: payments.size,
          count_paid_done:,
          payments: payment_history,
          pagination: pagy_metadata(@pagy)
        }, status: :ok
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

      # PATCH /api/v1/users/:id/update_locale
      def update_locale
        if @user.update(locale: params[:locale])
          # Update the current locale for this request
          I18n.locale = @user.locale
          invalidate_user_cache(@user)
          render json: {
            success: true,
            message: I18n.t('messages.success.updated', resource: I18n.t('activerecord.attributes.user.locale')),
            user: @user.as_json(only: fields_for_render)
          }, status: :ok
        else
          render json: {
            success: false,
            errors: @user.errors.full_messages
          }, status: :unprocessable_content
        end
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
        User.find(params[:password_change][:userId])
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, errors: ['User not found'] }, status: :not_found
        nil
      end

      def handle_admin_password_change(user)
        if user.update(password: new_pass, password_confirmation: new_pass)
          invalidate_user_cache(user)
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
        %i[id full_name identity rtn email address phone role status created_by created_at note locale]
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
          :status,
          :credit_score,
          :locale
        )
      end

      # Apply filters specific to payment history
      def apply_payment_history_filters(scope, params)
        return scope if params.blank?

        # Apply standard filters (status, search_term, date range, amount range)
        scope = apply_filters(scope, params, PAYMENT_HISTORY_SEARCHABLE_FIELDS)

        # Apply payment-specific filters
        scope = apply_payment_type_filter(scope, params[:payment_type]) if params[:payment_type].present?
        scope = apply_payment_date_filters(scope, params) if payment_date_params_present?(params)
        scope = apply_date_range_filter(scope, params[:date_range]) if params[:date_range].present?

        scope
      end

      # Filter by payment type
      def apply_payment_type_filter(scope, payment_type_param)
        payment_types = parse_statuses(payment_type_param) # Reuse the status parsing logic
        return scope if payment_types.empty?

        scope.where(payment_type: payment_types)
      end

      # Apply payment-specific date range filters
      def apply_payment_date_filters(scope, params)
        scope_with_date_filters = scope

        # Payment date range
        if params[:payment_start_date].present?
          payment_start_date = parse_date(params[:payment_start_date])
          if payment_start_date
            scope_with_date_filters = scope_with_date_filters.where('payment_date >= ?',
                                                                    payment_start_date)
          end
        end

        if params[:payment_end_date].present?
          payment_end_date = parse_date(params[:payment_end_date])
          if payment_end_date
            scope_with_date_filters = scope_with_date_filters.where('payment_date <= ?',
                                                                    payment_end_date.end_of_day)
          end
        end

        # Due date range
        if params[:due_start_date].present?
          due_start_date = parse_date(params[:due_start_date])
          scope_with_date_filters = scope_with_date_filters.where('due_date >= ?', due_start_date) if due_start_date
        end

        if params[:due_end_date].present?
          due_end_date = parse_date(params[:due_end_date])
          if due_end_date
            scope_with_date_filters = scope_with_date_filters.where('due_date <= ?',
                                                                    due_end_date.end_of_day)
          end
        end

        # Approved date range
        if params[:approved_start_date].present?
          approved_start_date = parse_date(params[:approved_start_date])
          if approved_start_date
            scope_with_date_filters = scope_with_date_filters.where('approved_at >= ?',
                                                                    approved_start_date)
          end
        end

        if params[:approved_end_date].present?
          approved_end_date = parse_date(params[:approved_end_date])
          if approved_end_date
            scope_with_date_filters = scope_with_date_filters.where('approved_at <= ?',
                                                                    approved_end_date.end_of_day)
          end
        end

        scope_with_date_filters
      end

      # Check if payment-specific date parameters are present
      def payment_date_params_present?(params)
        params[:payment_start_date].present? || params[:payment_end_date].present? ||
          params[:due_start_date].present? || params[:due_end_date].present? ||
          params[:approved_start_date].present? || params[:approved_end_date].present?
      end

      # Apply date range filter for predefined ranges (month, quarter)
      def apply_date_range_filter(scope, date_range)
        return scope if date_range.blank?

        case date_range.downcase
        when 'month'
          # Filter payments from the beginning of the current month
          start_date = Date.current.beginning_of_month
          scope.where('payments.due_date >= ?', start_date)
        when 'quarter'
          # Filter payments from the beginning of the current quarter
          start_date = Date.current.beginning_of_quarter
          scope.where('payments.due_date >= ?', start_date)
        when 'year'
          # Filter payments from the beginning of the current year
          start_date = Date.current.beginning_of_year
          scope.where('payments.due_date >= ?', start_date)
        else
          # Unknown date range, return scope unchanged
          scope
        end
      end
    end
  end
end
