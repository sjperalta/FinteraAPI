# app/services/payments/approve_payment_service.rb

module Payments
  class ApprovePaymentService
    def initialize(payment:)
      @payment = payment
    end

    def call
      @payment.transaction do
        @payment.approve!
        update_balance
        send_approval_notification
      end
      true
      rescue => e
        Rails.logger.error("Error aprobando el pago: #{e.message}")
        false
      end
    end

    private

    def update_balance
      @payment.contract.update_balance(@payment.amount)
    end

    def send_approval_notification
      UserMailer.with(user: payment.contract.applicant_user, payment: @payment).payment_approved.deliver_now
    end
  end
end
