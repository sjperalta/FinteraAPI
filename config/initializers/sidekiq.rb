require 'sidekiq'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    schedule_file = Rails.root.join('config/schedule.yml')
    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
      Rails.logger.info "Cron jobs loaded from #{schedule_file}"
    else
      Rails.logger.warn "No schedule file found at #{schedule_file}"
    end
  end
end
