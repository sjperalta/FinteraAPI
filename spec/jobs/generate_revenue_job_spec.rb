# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateRevenueJob, type: :job do
  include ActiveJob::TestHelper

  after { clear_enqueued_jobs }

  it 'enqueues on the default queue' do
    expect(GenerateRevenueJob).to receive(:perform_later)
    GenerateRevenueJob.perform_later
  end

  it 'calls the Statistics::RevenueService to generate revenue' do
    service = class_double('Statistics::RevenueService').as_stubbed_const
    expect(service).to receive(:generate_for_current_month)

    perform_enqueued_jobs do
      GenerateRevenueJob.perform_now
    end
  end
end
