# app/mailers/admin_mailer.rb

class AdminMailer < ApplicationMailer
  default from: 'no-reply@yourapp.com'

  # Método para enviar la notificación al administrador cuando un usuario sube un comprobante de pago
  def payment_receipt_uploaded
    @payment = params[:payment]
    @contract = params[:contract]

    mail(to: 'admin@yourapp.com', subject: 'Nuevo comprobante de pago subido')
  end
end
