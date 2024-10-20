class UserMailer < ApplicationMailer
  default from: 'no-reply@yourapp.com'

  # Método compartido para establecer el usuario
  before_action :set_user

  # Enviar correo con el contrato de reserva aprobado
  def contract_email(contract)
    @contract = contract
    mail(to: @user.email, subject: 'Contrato de Reserva Aprobado')
  end

  # Enviar correo cuando el pago es aprobado
  def payment_approved(payment)
    @payment = payment
    @contract = @payment.contract
    mail(to: @user.email, subject: 'Pago aprobado')
  end

  private

  # Método para establecer el usuario de los parámetros
  def set_user
    @user = params[:user]
    raise ArgumentError, 'User is required to send email' unless @user.present?
  end
end
