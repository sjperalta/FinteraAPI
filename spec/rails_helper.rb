# spec/rails_helper.rb

# Este archivo es generado automáticamente por el comando `rails generate rspec:install`
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# Ensure tests don't attempt to send events to Sentry unless explicitly enabled
ENV['SENTRY_DSN'] ||= ''
ENV['SENTRY_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)

# Si la base de datos necesita migrarse, abortar si el entorno de producción está activo
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'

# Requiere los archivos de soporte dentro de spec/support/
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Verifica que las migraciones estén al día antes de las pruebas
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  # Use pluralized fixture_paths to avoid Rails 7.1 deprecation
  config.fixture_paths = ["#{::Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
