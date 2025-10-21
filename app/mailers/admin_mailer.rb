# frozen_string_literal: true

# app/mailers/admin_mailer.rb

# Mailer class to handle admin-related email notifications.
class AdminMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_EMAIL', 'no-reply@updates.securexapp.com')

  # Método para enviar la notificación al administrador cuando un usuario sube un comprobante de pago
  def payment_receipt_uploaded
    @payment = params[:payment]
    @reservation = @payment.contract
    to_address = Rails.env.development? ? 'delivered+admin@resend.dev' : ENV.fetch('ADMIN_EMAIL', nil)
    mail(to: to_address, subject: 'Nuevo recibo de pago subido')
  end
end
