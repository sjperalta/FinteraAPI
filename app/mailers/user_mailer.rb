# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: ENV['DEFAULT_EMAIL']

  # Método compartido para establecer el usuario
  before_action :set_user

  # Método para enviar el correo de aprobación de pago
  def contract_submitted
    @contract = params[:contract]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.contract_submitted.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def contract_approved
    @contract = params[:contract]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.contract_approved.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def payment_approved
    @payment = params[:payment]
    @contract = @payment.contract
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.payment_approved.subject'))
  end

  # Método para enviar el correo de pagos vencidos
  def overdue_payment_email
    @payments = params[:payments]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.overdue_payment_email.subject'))
  end

  # Método para enviar el correo de reserva aprobada
  def reservation_approved
    @contract = params[:contract]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.reservation_approved.subject'))
  end

  def reset_code_email
    @user = params[:user]
    @code = params[:code]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.reset_code_email.subject'))
  end

  private

  # Método para establecer el usuario de los parámetros
  def set_user
    @user = params[:user]
    raise ArgumentError, 'User is required to send email' unless @user.present?
  end
end
