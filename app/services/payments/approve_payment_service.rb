# app/services/payments/approve_payment_service.rb
module Payments
  class ApprovePaymentService
    attr_reader :payment, :errors

    def initialize(payment:)
      @payment = payment
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        begin
          if payment.may_approve?
            payment.approve!
            send_approval_notification

            { success: true, message: 'Payment approved successfully', payment: payment }
          else
            add_error("Cannot approve payment in current state: #{payment.status}")
            { success: false, message: 'Failed to approve payment', errors: errors }
          end
        rescue AASM::InvalidTransition => e
          handle_error(e)
          { success: false, message: 'Invalid state transition', errors: errors }
        rescue StandardError => e
          handle_error(e)
          { success: false, message: 'Failed to approve payment', errors: errors }
        end
      end
    end

    private

    def send_approval_notification
      SendPaymentApprovalNotificationJob.perform_now(payment.id)
    end

    def handle_error(error)
      error_message = "Error approving payment: #{error.message}"
      Rails.logger.error(error_message)
      Rails.logger.error(error.backtrace.join("\n"))
      add_error(error_message)
    end

    def add_error(message)
      @errors << message
    end
  end
end
