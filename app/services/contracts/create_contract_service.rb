# frozen_string_literal: true

# app/services/contracts/create_contract_service.rb
module Contracts
  # Service to handle the creation of a contract along with associated user and documents.
  class CreateContractService
    include ContractCacheInvalidation
    include LotCacheInvalidation

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
      contract = nil
      ActiveRecord::Base.transaction do
        # Lock the lot to prevent race conditions
        lot.lock!
        validate_lot_availability
        user = process_user
        contract = create_contract(user)
        process_documents(contract)
        update_lot_status
        submit_contract(contract)
        send_reservation_notification(contract)
        after_submission(contract)
      end

      # Invalidate cache after successful contract creation
      if contract&.persisted?
        invalidate_contract_cache(contract)
        invalidate_lot_cache(contract.lot) # Lot status changed to 'reserved'
      end

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

    private

    def new_user?
      contract_params[:applicant_user_id].blank?
    end

    def validate_lot_availability
      # Check if lot is available for reservation (not reserved, sold, or cancelled)
      available_statuses = %w[available active] # Adjust based on your Lot model statuses
      return if available_statuses.include?(lot.status)

      message = I18n.t('notifications.messages.lot_not_available', lot_name: lot.name, status: lot.status)
      raise StandardError, "lot_not_available: #{message}"
    end

    def process_user
      if new_user?
        create_new_user
      else
        update_existing_user
      end
    end

    def create_new_user
      # Build user and ensure a temporary password exists so validations pass.
      user = User.new(permitted_user_params.merge(role: 'user'))
      user.creator = current_user

      # If no password was provided, generate a temporary one and set confirmation.
      temp_password = nil
      if user.password.blank?
        temp_password = ::SecureRandom.hex(8)
        user.password = temp_password
        user.password_confirmation = temp_password
      end

      # Avoid sending Devise confirmation emails during user creation in service
      # (tests and environments that don't have mailer configured can fail otherwise)
      user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)

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
        begin
          contract.documents.attach(document)
        rescue StandardError => e
          Rails.logger.error("Failed to attach document #{document.respond_to?(:original_filename) ? document.original_filename : 'unknown'}: #{e.message}")
        end
      end
    end

    def validate_document(document)
      return if valid_document?(document)

      # Raise a plain error for invalid documents to avoid constructing
      # ActiveRecord::RecordInvalid with a non-model object (which can cause
      # downstream code to call `.errors` on a String and blow up).
      raise StandardError, "Invalid document format or size: #{document.original_filename}"
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
      # Use update! with status check to ensure atomicity
      lot.update!(status: 'reserved') unless lot.status == 'reserved'
    end

    def submit_contract(contract)
      contract.submit!
    end

    def notify_new_user_creation(user, temp_password = nil)
      user_message = I18n.t('notifications.messages.user_account_created')
      if temp_password.present?
        user_message += I18n.t('notifications.messages.user_temp_password',
                               password: temp_password)
      end

      Notification.create!(
        user:,
        title: I18n.t('notifications.types.create_new_user'),
        message: user_message,
        notification_type: 'create_new_user'
      )

      # Notify admins
      User.admins.each do |admin|
        Notification.create!(
          user: admin,
          title: I18n.t('notifications.types.create_new_user'),
          message: I18n.t('messages.success.created', resource: I18n.t('activerecord.models.user')),
          notification_type: 'create_new_user'
        )
      end
    end

    def send_reservation_notification(contract)
      Notification.create!(
        user: contract.applicant_user,
        title: I18n.t('notifications.types.lot_reserved'),
        message: I18n.t('notifications.messages.lot_reservation_success', lot_name: contract.lot.name),
        notification_type: 'lot_reserved'
      )

      # Notify admins
      User.admins.each do |admin|
        Notification.create!(
          user: admin,
          title: I18n.t('notifications.types.lot_reserved'),
          message: I18n.t('notifications.messages.lot_reserved_admin',
                          lot_name: contract.lot.name,
                          user_name: contract.applicant_user.full_name),
          notification_type: 'lot_reserved'
        )
      end
    end

    def handle_error(message)
      Rails.logger.error(message)
      errors << message
    end

    def after_submission(contract)
      # Handle mailer failures gracefully - don't let them break the contract creation

      NotifyContractSubmissionJob.perform_now(contract)
    rescue StandardError => e
      # Log the error but don't fail the transaction
      Rails.logger.error("Failed to send contract submission notification: #{e.message}")
      # Could also create a notification for admins about the mailer failure
      begin
        Notification.create!(
          user: User.admins.first, # Notify at least one admin
          title: I18n.t('notifications.types.mailer_error'),
          message: I18n.t('notifications.messages.mailer_error_details', contract_id: contract.id, error: e.message),
          notification_type: 'system_error'
        )
      rescue StandardError
        nil
      end
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
