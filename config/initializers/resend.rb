# frozen_string_literal: true

require Rails.root.join('lib/resend_delivery')

Resend.api_key = ENV.fetch('RESEND_API_KEY', nil)

ActionMailer::Base.add_delivery_method :resend, ResendDelivery
