require 'rails_helper'

RSpec.describe Project, type: :model do
  subject { described_class.new(name: 'P', description: 'Desc', address: 'Addr', price_per_square_vara: 10.0, interest_rate: 1.0, commission_rate: 5.0) }

  it 'is valid with required attributes' do
    expect(subject).to be_valid
  end

  it 'generates a guid before create' do
    expect(SecureRandom).to receive(:uuid).and_return('GUID-123')
    # invoke the callback method directly instead of saving to DB
    subject.send(:generate_guid)
    expect(subject.guid).to eq('GUID-123')
  end
end
