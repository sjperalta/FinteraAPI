# frozen_string_literal: true

# app/services/notifications/admin_payment_receipt_notification_service.rb

module Notifications
  class AdminPaymentReceiptNotificationService
    def initialize(payment)
      @payment = payment
      @admin_email = ENV.fetch('ADMIN_EMAIL', nil) # Puedes configurar esto dinámicamente si tienes múltiples administradores
    end

    def call
      send_admin_notification_email
    end

    private

    def send_admin_notification_email
      AdminMailer.with(payment: @payment).payment_receipt_uploaded.deliver_now
    end
  end
end
