Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = ENV["SENTRY_ENV"] || Rails.env
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  # Adjust traces_sample_rate as needed for performance monitoring
  config.traces_sample_rate = (ENV["SENTRY_TRACES_SAMPLE_RATE"] || 0.0).to_f
  # Integrations
  config.instrumenter = :active_support
end

# Load Sidekiq integration only when Sidekiq is present.
# The sentry-sidekiq gem will register middleware on require.
begin
  if defined?(Sidekiq)
    require "sentry/sidekiq"
  end
rescue LoadError => e
  Rails.logger.warn "Sentry Sidekiq integration not available: #{e.message}"
end
