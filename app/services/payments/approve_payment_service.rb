# frozen_string_literal: true

# app/services/payments/approve_payment_service.rb
module Payments
  class ApprovePaymentService
    attr_reader :payment, :errors

    def initialize(payment:, payment_params: nil)
      @payment = payment
      @payment_params = payment_params
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        # Assign attributes if provided (for apply case)
        unless payment || @payment_params
          return { success: false, message: 'Payment not found or not provided',
                   errors: ['Payment not found or not provided'] }
        end

        payment.assign_attributes(@payment_params)
        payment.payment_date = Time.current

        if payment.may_approve?
          payment.approve!
          send_approval_notification
          # Trigger credit score calculation
          UpdateCreditScoresJob.perform_later(payment.contract.applicant_user.id)

          { success: true, message: 'Pago Aplicado Correctamente', payment: }
        else
          message = "No se puede aprobar o aplicar el pago en el estado actual: #{payment.status}"
          add_error(message)
          { success: false, message:, errors: }
        end
      rescue AASM::InvalidTransition => e
        handle_error(e)
        { success: false, message: 'Transición inválida', errors: }
      rescue StandardError => e
        handle_error(e)
        { success: false, message: 'No se puede aplicar pago', errors: }
      end
    end

    private

    def send_approval_notification
      SendPaymentApprovalNotificationJob.perform_now(payment.id)
    end

    def handle_error(error)
      error_message = "Error approving/applying payment: #{error.message}"
      Rails.logger.error(error_message)
      Rails.logger.error(error.backtrace.join("\n"))
      add_error(error_message)
    end

    def add_error(message)
      @errors << message
    end
  end
end
