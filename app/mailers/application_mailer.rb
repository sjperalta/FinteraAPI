# frozen_string_literal: true

# app/mailers/application_mailer.rb
# Base mailer class from which all other mailers inherit.
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('DEFAULT_EMAIL', 'Fintera <no-reply@notifications.securexapp.com>')
  layout 'mailer'
end
