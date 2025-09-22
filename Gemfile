# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.6'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.0', '>= 8.0.1'

# Use PostgreSQL as the database for Active Record
gem 'pg', '~> 1.5'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 6.0'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.0'

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

# Authentication and Authorization
gem 'cancancan'
gem 'devise'
gem 'paper_trail', '~> 16.0'

# JSON Web Tokens
gem 'jwt'

# API Documentation
gem 'rswag'
gem 'rswag-api'
gem 'rswag-specs'
gem 'rswag-ui'

# Background Job Processing
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-scheduler'

# Pagination
gem 'pagy'

# Environment Variables Management
gem 'dotenv-rails', groups: %i[development test]

# Logging and Boot Optimizations
gem 'bootsnap', require: false

# Onesignal Email
gem 'onesignal-rails-plugin', '~> 1.0.0'

# Status Transition
gem 'aasm'

# CSV reporting
gem 'csv'

# PDF reporting
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'

# Sentry for error tracking
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'sentry-sidekiq'

group :development, :test do
  gem 'rubocop', require: false
  # Testing Framework
  gem 'rspec-rails'

  # Debugging Tools
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'pry-byebug', '~> 3.10'
  gem 'pry-rails'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'discard', '~> 1.4'
