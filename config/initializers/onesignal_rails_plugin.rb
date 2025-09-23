# frozen_string_literal: true

OneSignal::Rails::Plugin.configure do |c|
  c.app_key = ENV.fetch('ONE_SIGNAL_APP_KEY', nil)
  c.app_id = ENV.fetch('ONE_SIGNAL_APP_ID', nil)
end
