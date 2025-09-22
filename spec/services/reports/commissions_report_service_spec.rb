# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::CommissionsReportService do
  let(:start_date) { Date.new(2020, 1, 1) }
  let(:end_date) { Date.new(2025, 12, 31) }

  it 'generates localized headers and computes commission' do
    project = double('Project', commission_rate: 5.0, name: 'Proyecto')
    lot = double('Lot', project:, name: 'Lote A')
    creator = double('User', full_name: 'Creator Name')
    contract = double('Contract', creator_id: 10, creator:, approved_at: Date.today, lot:, amount: 1000.0)
    relation = double('Relation')

    allow(Contract).to receive(:approved_between).and_return(relation)
    allow(relation).to receive(:with_creator_and_lot).and_return([contract])

    csv = described_class.new(start_date, end_date).call(locale: :es)
    parsed = CSV.parse(csv)
    headers = parsed[0]
    expect(headers).to include(I18n.t('reports.commissions.csv.headers.user_id', locale: :es))
    # check computed commission value present
    expect(csv).to include('50.0')
  end
end
