# frozen_string_literal: true

# app/mailers/user_mailer.rb
# Mailer class to handle user-related email notifications.
class UserMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_EMAIL', nil)

  # Método compartido para establecer el usuario
  before_action :set_user

  # Método para enviar el correo de aprobación de pago
  def contract_submitted
    @contract = params[:contract]
    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @contract.applicant_user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.contract_submitted.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def contract_approved
    @contract = params[:contract]
    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.contract_approved.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def payment_approved
    @payment = params[:payment]
    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.payment_approved.subject'))
  end

  # Método para enviar el correo de pagos vencidos
  def overdue_payment_email
    @payments = params[:payments]
    mail(to: @user.email, subject: I18n.t('mailers.user_mailer.overdue_payment_email.subject'))
  end

  # Método para enviar el correo de reserva aprobada
  def reservation_approved
    @contract = params[:contract] || params[:reservation]&.contract
    @reservation = params[:reservation]
    raise ArgumentError, 'Contract is required to send reservation approved email' unless @contract

    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.reservation_approved.subject'))
  end

  def reset_code_email
    @code = params[:code]
    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.reset_code_email.subject'))
  end

  # Email sent when a new account is created by admin/service, possibly with a temporary password
  def account_created
    @user = params[:user]
    @temp_password = params[:temp_password]

    subject = I18n.t('mailers.user_mailer.account_created.subject', default: 'Cuenta creada')
    mail(to: @user.email, subject:)
  end

  # Welcome email for new users
  def welcome_email(user)
    @user = user
    to_address = Rails.env.development? ? "delivered+user#{user.id}@resend.dev" : user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.welcome.subject'))
  end

  def reset_password
    @reset_token = params[:reset_token]
    to_address = Rails.env.development? ? "delivered+user#{@user.id}@resend.dev" : @user.email
    mail(to: to_address, subject: I18n.t('mailers.user_mailer.reset_password.subject'))
  end

  private

  # Método para establecer el usuario de los parámetros
  def set_user
    @user = params[:user]
    raise ArgumentError, 'User is required to send email' unless @user.present?
  end
end
