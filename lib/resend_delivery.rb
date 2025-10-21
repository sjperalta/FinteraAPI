# frozen_string_literal: true

require 'resend'

# Custom ActionMailer delivery method using Resend.com
class ResendDelivery
  DEFAULT_FROM = 'Fintera <no-reply@updates.securexapp.com>'

  attr_reader :settings

  def initialize(values = {})
    @settings = values
  end

  def deliver!(mail)
    configure_api_key!

    response = if multiple_recipients?(mail)
                 Resend::Batch.send(build_batch_params(mail))
               else
                 Resend::Emails.send(build_email_params(mail))
               end

    log_response(response)
  rescue StandardError => e
    Rails.logger.error("Resend delivery failed: #{e.message}")
    raise
  end

  private

  def configure_api_key!
    api_key = settings[:api_key] || ENV.fetch('RESEND_API_KEY', nil)
    raise ArgumentError, 'RESEND_API_KEY is not configured' if api_key.blank?

    Resend.api_key = api_key
  end

  def multiple_recipients?(mail)
    Array.wrap(mail.to).size > 1
  end

  def build_email_params(mail)
    {
      from: formatted_from(mail),
      to: Array.wrap(mail.to),
      subject: mail.subject,
      html: body_content(mail, :html),
      text: body_content(mail, :text),
      reply_to: Array.wrap(mail.reply_to).first
    }.compact
  end

  def build_batch_params(mail)
    base_params = build_email_params(mail)

    Array.wrap(mail.to).map do |recipient|
      base_params.merge(to: [recipient])
    end
  end

  def formatted_from(mail)
    sender = Array.wrap(mail.from).first
    sender.presence || settings[:default_from] || ENV['DEFAULT_EMAIL'] || DEFAULT_FROM
  end

  def body_content(mail, type)
    case type
    when :html
      html_part = mail.html_part&.body&.decoded
      return html_part if html_part.present?

      mail.content_type&.include?('text/html') ? mail.body.decoded : nil
    when :text
      text_part = mail.text_part&.body&.decoded
      return text_part if text_part.present?

      mail.content_type&.include?('text/plain') ? mail.body.decoded : nil
    end
  end

  def log_response(response)
    if response.is_a?(Array)
      response.each do |entry|
        log_entry(entry)
      end
    else
      log_entry(response)
    end
  end

  def log_entry(entry)
    identifier = entry.respond_to?(:dig) ? (entry['id'] || entry[:id]) : nil
    message = identifier.present? ? "Resend email sent with id: #{identifier}" : "Resend response: #{entry.inspect}"
    Rails.logger.info(message)
  end
end
