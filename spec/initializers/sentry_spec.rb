require "rails_helper"

RSpec.describe "Sentry initializer" do
  let(:dsn) { "https://example@sentry.io/123" }

  around do |example|
    original = ENV["SENTRY_DSN"]
    ENV["SENTRY_DSN"] = dsn
    load Rails.root.join("config/initializers/sentry.rb")
    example.run
    ENV["SENTRY_DSN"] = original
  end

  it "configures Sentry with DSN from ENV" do
    expect(defined?(Sentry)).to be_truthy
    # Sentry.configuration.dsn returns a Sentry::DSN object; compare its string form
    expect(Sentry.configuration.dsn.to_s).to eq(dsn)
    expect(Sentry.configuration.environment).to eq(Rails.env)
  end
end
