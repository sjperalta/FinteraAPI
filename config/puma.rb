# frozen_string_literal: true

# Set the number of workers (processes) based on ENV variable, defaults to 2
workers Integer(ENV.fetch('WEB_CONCURRENCY', 2))

# Configure threads per worker (min, max) based on ENV variable, defaults to 5
threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads threads_count, threads_count

preload_app!

# Bind to IPv6 (::) or IPv4 (0.0.0.0) based on ENV variable
bind "tcp://#{ENV.fetch('BIND_ADDRESS', '0.0.0.0')}:#{ENV.fetch('PORT', 3000)}"

# Turn off keepalive support (temporary fix for Router 2.0 issue)
enable_keep_alives(false) if respond_to?(:enable_keep_alives)

# Use rackup for starting the app
rackup DefaultRackup if defined?(DefaultRackup)

# Set the environment (defaults to development)
environment ENV.fetch('RAILS_ENV', 'development')

# Worker-specific setup
on_worker_boot do
  # Establish database connection for each worker
  ActiveRecord::Base.establish_connection
end

# Allow for phased restarts (zero-downtime deploys)
plugin :tmp_restart
