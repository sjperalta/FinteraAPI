require 'rails_helper'

RSpec.describe Authentication::RefreshTokenService do
  # Ensure tests have a secret key for JWT encoding/decoding
  before(:all) { ENV['SECRET_KEY_BASE'] ||= 'test_secret_for_specs' }

  let(:user) do
    User.create!(
      email: 'user@example.com',
      full_name: 'Test User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '0000000001',
      identity: '1234567891',
      rtn: '1234567891',
      role: 'user',
      status: 'active',
      locale: 'es',
      confirmed_at: Time.current
    )
  end
  let(:refresh_token) { SecureRandom.hex(64) }
  let(:expires_at) { 30.days.from_now }
  let(:token_record) { RefreshToken.create!(user:, token: refresh_token, expires_at:) }
  let(:service) { described_class.new(refresh_token:) }

  describe '#call' do
    context 'with valid refresh token' do
      before do
        token_record
      end

      it 'returns success with new tokens' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:token]).to be_present
        expect(result[:refresh_token]).to be_present
        expect(result[:user]).to eq(user.as_json(only: %i[id full_name address identity rtn email phone role status
                                                          locale]))
      end

      it 'destroys the old refresh token' do
        expect { service.call }.to change(RefreshToken, :count).by(0)
      end

      it 'creates a new refresh token' do
        service.call

        new_token_record = RefreshToken.last
        expect(new_token_record.user).to eq(user)
        expect(new_token_record.token).not_to eq(refresh_token)
        expect(new_token_record.expires_at).to be_within(1.minute).of(30.days.from_now)
      end
    end

    context 'with blank refresh token' do
      let(:service) { described_class.new(refresh_token: '') }

      it 'returns error for blank token' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.invalid_refresh_token'))
      end
    end

    context 'with non-existent refresh token' do
      it 'returns error for invalid token' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.invalid_refresh_token'))
      end
    end

    context 'with expired refresh token' do
      let(:expired_token_record) { RefreshToken.create!(user:, token: refresh_token, expires_at: 1.day.ago) }

      before { expired_token_record }

      it 'returns error and destroys expired token' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.refresh_token_expired'))
        expect(RefreshToken.exists?(expired_token_record.id)).to be false
      end
    end

    context 'when user is deleted after token creation' do
      before do
        token_record
        user.discard!
      end

      it 'returns error when user not found' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end

    context 'when token rotation fails' do
      before do
        token_record
        expect(RefreshToken).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)
      end

      it 'returns error for rotation failure' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.refresh_rotation_failed'))
      end
    end
  end
end
