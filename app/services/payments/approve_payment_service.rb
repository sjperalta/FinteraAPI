# frozen_string_literal: true

# app/services/payments/approve_payment_service.rb
module Payments
  # Service to approve or apply a payment
  class ApprovePaymentService
    include PaymentCacheInvalidation
    include ContractCacheInvalidation

    attr_reader :payment, :errors

    def initialize(payment:, payment_params: nil)
      @payment = payment
      @payment_params = payment_params
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        # Assign attributes if provided (for apply case)
        if @payment.nil? || @payment_params.nil?
          return { success: false, message: 'Payment not found or not provided',
                   errors: ['Payment not found or not provided'] }
        end

        @payment.assign_attributes(@payment_params)
        # in case the payment date is not set, set it to current time
        @payment.payment_date = Date.current if @payment.payment_date.nil?

        if @payment.may_approve?
          @payment.approve!
          send_approval_notification
          # Trigger credit score calculation
          UpdateCreditScoresJob.perform_later(@payment.contract.applicant_user.id)

          { success: true, message: 'Pago Aplicado Correctamente', payment: @payment }
        else
          reason = if @payment.status == 'approved'
                     "El pago ya fue aprobado (estado actual: #{@payment.status})"
                   elsif !%w[pending submitted].include?(@payment.status)
                     "El pago no está en estado pendiente o enviado (estado actual: #{@payment.status})"
                   elsif !@payment.contract.active? || @payment.contract.status == 'closed'
                     "El contrato asociado no está activo o está cerrado (estado actual: #{@payment.contract.status})"
                   elsif (@payment.contract.balance.to_d - @payment.paid_amount.to_d) <= 0
                     "El pago excede el monto adeudado #{@payment.contract.balance.to_d}, monto a pagar: #{@payment.paid_amount.to_d}"
                   else
                     "No se puede aprobar el pago por razones desconocidas, balance: #{@payment.contract.balance.to_d}"
                   end
          message = "No se puede aprobar el pago: #{reason}"
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
      SendPaymentApprovalNotificationJob.perform_now(@payment.id)
    rescue StandardError => e
      # Log the error but don't fail the payment approval
      Rails.logger.error("Failed to send payment approval notification for payment ##{@payment.id}: #{e.message}")
      # Could also create a notification for admins about the email failure
      begin
        Notification.create!(
          user: User.admins.first,
          title: I18n.t('notifications.types.system_error'),
          message: I18n.t('notifications.messages.payment_notification_failed', payment_id: @payment.id,
                                                                                error: e.message),
          notification_type: 'system_error'
        )
      rescue StandardError
        # If even the notification creation fails, just log it
        Rails.logger.error('Failed to create admin notification for payment approval email failure')
      end
    end

    def handle_error(error)
      error_message = "Error aprobando el pago: #{error.message}"
      Rails.logger.error(error_message)
      Rails.logger.error(error.backtrace.join("\n"))
      add_error(error_message)
    end

    def add_error(message)
      @errors << message
    end
  end
end
