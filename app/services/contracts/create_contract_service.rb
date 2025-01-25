module Contracts
  class CreateContractService
    def initialize(lot:, contract_params:, user_params:, documents:, current_user:)
      @lot = lot
      @contract_params = contract_params
      @user_params = user_params
      @documents = documents
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        user = find_or_create_or_update_user
        contract = create_contract(user)
        attach_documents(contract) if @documents.present?
        update_lot_status

        { success: true, contract: contract }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, errors: e.record.errors.full_messages }
      rescue ActiveRecord::RecordNotFound => e
        { success: false, errors: [e.message] }
      end
    end

    private

    def find_or_create_or_update_user
      applicant_user_id = @contract_params[:applicant_user_id]

      if applicant_user_id.to_i == 0
        # Create a new user
        user = User.new(
          full_name: @user_params[:full_name],
          phone: @user_params[:phone],
          identity: @user_params[:identity],
          rtn: @user_params[:rtn],
          email: @user_params[:email],
          role: 'user' # Assuming 'user' is the default role for applicants
        )
        user.creator = @current_user # Assuming there's a `creator` association
        user.save! # Raises an exception if validation fails
        #user.send_confirmation_instructions if user.respond_to?(:send_confirmation_instructions)
        user
      else
        # Update existing user
        user = User.find(applicant_user_id)
        user.update!(
          full_name: @user_params[:full_name],
          phone: @user_params[:phone],
          identity: @user_params[:identity],
          rtn: @user_params[:rtn],
          email: @user_params[:email]
        )
        user
      end
    end

    def create_contract(user)
      contract = @lot.contracts.build(@contract_params)
      contract.active = true
      contract.applicant_user = user
      contract.creator = @current_user
      contract.save! # Raises an exception if validation fails
      contract
    end

    def attach_documents(contract)
      contract.documents.attach(@documents)
    end

    def update_lot_status
      @lot.update!(status: 'reserved')
    end
  end
end
