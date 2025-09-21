require 'rails_helper'

RSpec.describe Reports::OverduePaymentsReportService do
  let(:start_date) { Date.new(2020,1,1) }
  let(:end_date) { Date.new(2025,12,31) }

  it 'generates localized headers and totals' do
    payment = double('Payment', id: 1, contract: double('Contract', applicant_user: double('User', full_name: 'Juan', email: 'j@e', phone: '123')), description: 'Desc', amount: 50.0, interest_amount: 2.5, due_date: Date.new(2025,9,1))
    relation = double('Relation')

    allow(Payment).to receive_message_chain(:joins, :where, :where).and_return(relation)
    allow(relation).to receive(:sum).with(:amount).and_return(50.0)
    allow(relation).to receive(:sum).with(:interest_amount).and_return(2.5)
    allow(relation).to receive(:each).and_yield(payment)

    csv = described_class.new(start_date, end_date).call(locale: :es)
    parsed = CSV.parse(csv)
    headers = parsed[0]
    expect(headers).to include(I18n.t('reports.overdue_payments.csv.headers.id_payment', locale: :es))
    expect(csv).to include(I18n.t('reports.overdue_payments.total_amount', locale: :es))
  end
end
