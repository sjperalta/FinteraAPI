class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn "[#{job.class}] Discarding job due to deserialization error: #{error.message}"
    Sentry.capture_exception(error, level: :warning) if defined?(Sentry)
  end

  around_perform do |job, block|
    Rails.logger.info "[#{job.class}] Starting job, args=#{job.arguments.inspect}"
    # Let individual jobs decide how to handle exceptions to avoid duplicate logging/Sentry reports.
    block.call
    Rails.logger.info "[#{job.class}] Finished successfully"
  end
end
