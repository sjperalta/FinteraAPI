# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  # Load Sidekiq YAML configuration if exists
  sidekiq_config_path = Rails.root.join('config', 'sidekiq.yml')

  if File.exist?(sidekiq_config_path)
    sidekiq_config = YAML.load_file(sidekiq_config_path)

    # Set Sidekiq queue and concurrency settings from YAML
    config.queues = sidekiq_config[':queues'].map(&:to_s) if sidekiq_config[':queues']

    config.concurrency = sidekiq_config[':concurrency'].to_i if sidekiq_config[':concurrency']
  else
    Rails.logger.warn("Sidekiq config file not found: #{sidekiq_config_path}")
  end

  # Configure Redis
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load Sidekiq Scheduler (Cron Jobs)
  schedule_file = Rails.root.join('config', 'schedule.yml')
  if File.exist?(schedule_file)
    Sidekiq.schedule = YAML.load_file(schedule_file)
    Sidekiq::Scheduler.reload_schedule!
  else
    Rails.logger.warn("Sidekiq schedule file not found: #{schedule_file}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
