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
    begin
      block.call
      Rails.logger.info "[#{job.class}] Finished successfully"
    rescue StandardError => e
      Rails.logger.error "[#{job.class}] Failed: #{e.class} #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      Sentry.capture_exception(e) if defined?(Sentry)
      raise e
    end
  end
end
