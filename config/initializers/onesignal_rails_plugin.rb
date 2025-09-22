# frozen_string_literal: true

OneSignal::Rails::Plugin.configure do |c|
  c.app_key = ENV['ONE_SIGNAL_APP_KEY']
  c.app_id = ENV['ONE_SIGNAL_APP_ID']
end
