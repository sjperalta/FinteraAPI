class UserMailer < ApplicationMailer
  default from: ENV['DEFAULT_EMAIL']

  # Método compartido para establecer el usuario
  before_action :set_user

  # Método para enviar el correo de aprobación de pago
  def contract_submitted
    @contract = params[:contract]

    mail(to: @user.email, subject: 'Contracto Creado')
  end

  # Método para enviar el correo de aprobación de pago
  def contract_approved
    @contract = params[:contract]

    mail(to: @user.email, subject: 'Contracto Aprobado')
  end

  # Método para enviar el correo de aprobación de pago
  def payment_approved
    @payment = params[:payment]
    @contract = @payment.contract

    mail(to: @user.email, subject: 'Pago Aprobado - Detalles de tu transacción')
  end

  # Método para enviar el correo de pagos vencidos
  def overdue_payment_email
    @payments = params[:payments]

    mail(to: @user.email, subject: 'Pagos Vencidos')
  end

  def reset_code_email
    @user = params[:user]
    @code = params[:code]

    mail(to: @user.email, subject: "Codigo de reseteo")
  end

  private

  # Método para establecer el usuario de los parámetros
  def set_user
    @user = params[:user]
    raise ArgumentError, 'User is required to send email' unless @user.present?
  end
end
