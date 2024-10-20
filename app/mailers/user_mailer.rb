# app/mailers/user_mailer.rb

class UserMailer < ApplicationMailer
  def contract_email(user, contract)
    @user = user
    @contract = contract
    mail(to: @user.email, subject: 'Contrato de Reserva Aprobado')
  end
end
