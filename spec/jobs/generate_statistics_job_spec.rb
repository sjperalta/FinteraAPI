# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateStatisticsJob, type: :job do
  include ActiveJob::TestHelper

  after { clear_enqueued_jobs }

  it 'enqueues on the default queue' do
    expect(GenerateStatisticsJob).to receive(:perform_later)
    GenerateStatisticsJob.perform_later
  end

  it 'instantiates the service and calls #call for the given date' do
    date = Date.new(2025, 9, 1)
    service_double = instance_double('Statistics::GenerateStatisticsService')
    expect(Statistics::GenerateStatisticsService).to receive(:new).with(date).and_return(service_double)
    expect(service_double).to receive(:call)

    GenerateStatisticsJob.perform_now(date)
  end
end
