require 'rails_helper'

RSpec.describe Users::UserSummaryService, type: :service do
  let(:user) { instance_double('User', id: 1) }
  let(:payments_relation) { double('payments_relation') }

  subject(:service) { described_class.new(user) }

  before do
    allow(user).to receive(:payments).and_return(payments_relation)
  end

  it 'returns aggregated summary values using DB aggregates and joins' do
    # Currency: payments.joins(:contract).limit(1).pluck('contracts.currency').first => 'USD'
    allow(payments_relation).to receive_message_chain(:joins, :limit, :pluck).and_return(['USD'])

    # Balance: payments.pluck(COALESCE(SUM(amount),0), COALESCE(SUM(paid_amount),0)) => [1000, 600]
    allow(payments_relation).to receive(:pluck).with(an_instance_of(Arel::Nodes::SqlLiteral)).and_return([[1000.0, 600.0]])

    # Overdue aggregate: payments.where(...).where(...).pluck(...) => [200, 20, 2]
    allow(payments_relation).to receive_message_chain(:where, :where, :pluck).and_return([[200.0, 20.0, 2]])

    # Contract list: Contract.joins(lot: :project).where(applicant_user_id: user.id).distinct.pluck('projects.name')
    allow(Contract).to receive_message_chain(:joins, :where, :distinct, :pluck).and_return(['Project A'])

    result = service.call

    expect(result).to be_a(Hash)
    expect(result[:currency]).to eq('USD')
    expect(result[:balance]).to eq(400.0)
    expect(result[:totalDue]).to eq(200.0)
    expect(result[:totalFees]).to eq(20.0)
    expect(result[:overdueCount]).to eq(2)
    expect(result[:contractList]).to eq(['Project A'])
  end

  it 'returns defaults when there are no payments' do
    allow(payments_relation).to receive_message_chain(:joins, :limit, :pluck).and_return([nil])
    allow(payments_relation).to receive(:pluck).with(an_instance_of(Arel::Nodes::SqlLiteral)).and_return([[0, 0]])
    allow(payments_relation).to receive_message_chain(:where, :where, :pluck).and_return([[0, 0, 0]])
    allow(Contract).to receive_message_chain(:joins, :where, :distinct, :pluck).and_return([])

    result = service.call

    expect(result[:currency]).to eq('HNL')
    expect(result[:balance]).to eq(0.0)
    expect(result[:totalDue]).to eq(0.0)
    expect(result[:totalFees]).to eq(0.0)
    expect(result[:overdueCount]).to eq(0)
    expect(result[:contractList]).to eq([])
  end
end
