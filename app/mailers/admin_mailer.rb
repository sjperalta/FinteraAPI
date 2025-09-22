# frozen_string_literal: true

# app/mailers/admin_mailer.rb

class AdminMailer < ApplicationMailer
  default from: 'no-reply@yourapp.com'

  # Método para enviar la notificación al administrador cuando un usuario sube un comprobante de pago
  def payment_receipt_uploaded
    @payment = params[:payment]
    @reservation = @payment.contract

    mail(to: ENV['ADMIN_EMAIL'], subject: 'Nuevo recibo de pago subido')
  end
end
