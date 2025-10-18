# frozen_string_literal: true

if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.environment = ENV['SENTRY_ENV'] || Rails.env
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    # Adjust traces_sample_rate as needed for performance monitoring
    config.traces_sample_rate = (ENV['SENTRY_TRACES_SAMPLE_RATE'] || 0.3).to_f
    config.max_breadcrumbs = 5
    config.send_default_pii = true
    # Integrations
    config.instrumenter = :active_support
  end
else
  Rails.logger.info 'Sentry not configured (SENTRY_DSN not set); skipping initialization'
end
