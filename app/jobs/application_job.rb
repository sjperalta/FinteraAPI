# frozen_string_literal: true

# Base class for all ActiveJob jobs in the application.
class ApplicationJob < ActiveJob::Base
  # New class-level configuration to control whether unhandled exceptions
  # in a job should be swallowed (useful for fire-and-forget notification jobs).
  class_attribute :swallow_exceptions
  self.swallow_exceptions = false

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn "[#{job.class}] Discarding job due to deserialization error: #{error.message}"
    Sentry.capture_exception(error, level: :warning) if defined?(Sentry)
  end

  around_perform do |job, block|
    Rails.logger.info "[#{job.class}] Starting job, args=#{job.arguments.inspect}"
    begin
      block.call
      Rails.logger.info "[#{job.class}] Finished successfully"
    rescue StandardError => e
      Rails.logger.error "[#{job.class}] Unhandled error: #{e.class} #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)

      raise e unless job.class.swallow_exceptions

      Rails.logger.warn "[#{job.class}] Swallowing exception as configured"
      # swallow and finish

      # propagate to allow Sidekiq / ActiveJob to retry according to config
    end
  end
end
