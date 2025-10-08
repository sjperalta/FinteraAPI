# frozen_string_literal: true

# app/services/notifications/contract_approval_email_service.rb

module Notifications
  # Service to send contract approval email to the user
  class ContractApprovalEmailService
    def initialize(contract)
      @contract = contract
      @user = @contract.applicant_user # El usuario que solicitó el contrato
    end

    def call
      send_contract_approval_email
    end

    private

    def send_contract_approval_email
      UserMailer.with(user: @user, contract: @contract).contract_approved.deliver_now
    end
  end
end
