require 'rails_helper'

RSpec.describe RefreshToken, type: :model do
  describe 'associations and validations' do
    it 'belongs to user' do
      assoc = described_class.reflect_on_association(:user)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it 'validates presence of token' do
      rt = described_class.new(expires_at: 1.day.from_now)
      expect(rt).not_to be_valid
      expect(rt.errors[:token]).to include("can't be blank")
    end

    it 'validates presence of expires_at' do
      rt = described_class.new(token: SecureRandom.hex(16))
      expect(rt).not_to be_valid
      expect(rt.errors[:expires_at]).to include("can't be blank")
    end
  end
end
