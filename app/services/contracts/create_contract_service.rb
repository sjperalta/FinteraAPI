# frozen_string_literal: true

# app/services/contracts/create_contract_service.rb
module Contracts
  # Service to handle the creation of a contract along with associated user and documents.
  class CreateContractService
    attr_reader :lot, :contract_params, :user_params, :documents, :current_user, :errors

    def initialize(lot:, contract_params:, user_params:, documents:, current_user:)
      @lot = lot
      @contract_params = contract_params
      @user_params = user_params
      @documents = documents
      @current_user = current_user
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        user = process_user
        contract = create_contract(user)
        process_documents(contract)
        update_lot_status
        submit_contract(contract)
        after_submission(contract)

        { success: true, contract: }
      rescue ActiveRecord::RecordInvalid => e
        handle_error("Validation error: #{e.message}")
        { success: false, errors: }
      rescue AASM::InvalidTransition => e
        handle_error("State transition error: #{e.message}")
        { success: false, errors: }
      rescue StandardError => e
        handle_error("Unexpected error: #{e.message}")
        { success: false, errors: }
      end
    end

    private

    def process_user
      if new_user?
        create_new_user
      else
        update_existing_user
      end
    end

    def new_user?
      contract_params[:applicant_user_id].to_i.zero?
    end

    def create_new_user
      # Build user and ensure a temporary password exists so validations pass.
      user = User.new(permitted_user_params.merge(role: 'user'))
      user.creator = current_user

      # If no password was provided, generate a temporary one and set confirmation.
      temp_password = nil
      if user.password.blank?
        temp_password = SecureRandom.hex(8)
        user.password = temp_password
        user.password_confirmation = temp_password
      end

      raise ActiveRecord::RecordInvalid, user unless user.save

      # Notify the user and admins; include temporary password when generated so the user can log in
      notify_new_user_creation(user, temp_password)
      user
    end

    def update_existing_user
      user = User.find(contract_params[:applicant_user_id])

      raise ActiveRecord::RecordInvalid, user unless user.update(permitted_user_params)

      user
    end

    def create_contract(user)
      contract = lot.contracts.build(contract_attributes(user))

      raise ActiveRecord::RecordInvalid, contract unless contract.save

      contract
    end

    def contract_attributes(user)
      contract_params.merge(
        active: true,
        applicant_user: user,
        creator: current_user
      )
    end

    def process_documents(contract)
      return unless documents.present?

      documents.each do |document|
        validate_document(document)
        contract.documents.attach(document)
      end
    end

    def validate_document(document)
      return if valid_document?(document)

      raise ActiveRecord::RecordInvalid, "Invalid document format or size: #{document.original_filename}"
    end

    def valid_document?(document)
      valid_content_type?(document) && valid_size?(document)
    end

    def valid_content_type?(document)
      %w[application/pdf image/jpeg image/png].include?(document.content_type)
    end

    def valid_size?(document)
      document.size <= 10.megabytes
    end

    def update_lot_status
      lot.update!(status: 'reserved')
    end

    def submit_contract(contract)
      return unless contract.may_submit?

      contract.submit!

      # Notify reservation approval (new or existing user)
      SendReservationApprovalNotificationJob.perform_later(contract)
    end

    def notify_new_user_creation(user, temp_password = nil)
      # Keep the in-app notification message original (no temp password included)
      Notification.create!(
        user:,
        title: 'Bienvenido a Fintera',
        message: 'Se ha creado tu cuenta exitosamente',
        notification_type: 'create_new_user'
      )

      # Notify admins
      User.admins.each do |admin|
        Notification.create!(
          user: admin,
          title: 'Nuevo Usuario',
          message: "Se ha creado un nuevo usuario: #{user.full_name}",
          notification_type: 'create_new_user'
        )
      end

      # Send an email to the user including the temporary password (if any)
      begin
        UserMailer.with(user:, temp_password:).account_created.deliver_later
      rescue StandardError => e
        Rails.logger.error "Failed to enqueue account_created email for User##{user.id}: #{e.message}"
      end
    end

    def handle_error(message)
      Rails.logger.error(message)
      errors << message
    end

    def after_submission(contract)
      NotifyContractSubmissionJob.perform_now(contract)
    end

    def permitted_user_params
      @user_params.slice(
        :full_name,
        :phone,
        :identity,
        :rtn,
        :email,
        :password,
        :password_confirmation
      )
    end
  end
end
