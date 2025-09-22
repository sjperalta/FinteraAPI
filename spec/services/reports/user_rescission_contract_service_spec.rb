# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::UserRescissionContractService do
  it 'returns error when contract not found or not rescinded' do
    allow(Contract).to receive(:includes).and_return(Contract)
    allow(Contract).to receive(:find_by).and_return(nil)

    result = described_class.new(1).call
    expect(result[:success]).to be_falsey
    expect(result[:error]).to eq(I18n.t('reports.user_rescission.errors.not_found'))
  end
end
