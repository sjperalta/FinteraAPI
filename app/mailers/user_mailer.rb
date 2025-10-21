# frozen_string_literal: true

# app/mailers/user_mailer.rb
# Mailer class to handle user-related email notifications.
class UserMailer < ApplicationMailer
  default from: ENV.fetch('DEFAULT_EMAIL', 'no-reply@updates.securexapp.com')

  # Ensure @user is present for methods that rely on params[:user]
  before_action :set_user, except: %i[welcome_email]

  # Account created email (used when admin or service creates an account)
  # Expects params: :user, optional :temp_password
  def account_created
    @user = params[:user]
    @temp_password = params[:temp_password]

    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.account_created.subject'))
  end

  # Simple welcome email
  def welcome_email(user)
    @user = user
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.welcome.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def contract_submitted
    @contract = params[:contract]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.contract_submitted.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def contract_approved
    @contract = params[:contract]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.contract_approved.subject'))
  end

  # Método para enviar el correo de aprobación de pago
  def payment_approved
    @payment = params[:payment]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.payment_approved.subject'))
  end

  # Método para enviar el correo de pagos vencidos
  def overdue_payment_email
    @payments = params[:payments]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.overdue_payment_email.subject'))
  end

  # Método para enviar el correo de reserva aprobada
  def reservation_approved
    @contract = params[:contract] || params[:reservation]&.contract
    @reservation = params[:reservation]
    raise ArgumentError, 'Contract is required to send reservation approved email' unless @contract

    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.reservation_approved.subject'))
  end

  def reset_code_email
    @code = params[:code]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.reset_code_email.subject'))
  end

  def reset_password
    @reset_token = params[:reset_token]
    mail(to: development_address(@user.email), subject: I18n.t('mailers.user_mailer.reset_password.subject'))
  end

  private

  def set_user
    @user = params[:user]
    raise ArgumentError, 'User is required to send email' unless @user.present?
  end

  def development_address(real_email)
    return real_email unless Rails.env.development?
    return real_email unless @user&.id

    "delivered+user#{@user.id}@resend.dev"
  end
end
