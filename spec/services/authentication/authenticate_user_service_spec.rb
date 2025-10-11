require 'rails_helper'

RSpec.describe Authentication::AuthenticateUserService do
  # Ensure tests have a secret key for JWT encoding/decoding
  before(:all) { ENV['SECRET_KEY_BASE'] ||= 'test_secret_for_specs' }

  let(:user) do
    u = User.create!(
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
    # Ensure Devise encrypted_password is present and deterministic for tests
    u.update!(encrypted_password: Devise::Encryptor.digest(User, 'password123'))
    u
  end
  let(:inactive_user) do
    v = User.create!(
      email: 'inactive@example.com',
      full_name: 'Inactive User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '0000000002',
      identity: '1234567892',
      rtn: '1234567892',
      role: 'user',
      status: 'inactive',
      locale: 'es',
      confirmed_at: Time.current
    )
    v.update!(encrypted_password: Devise::Encryptor.digest(User, 'password123'))
    v
  end
  let(:service) { described_class.new(email:, password:) }
  let(:email) { user.email }
  let(:password) { 'password123' }

  describe '#call' do
    context 'with valid credentials and active user' do
      it 'returns success with tokens and user data' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:token]).to be_present
        expect(result[:refresh_token]).to be_present
        expect(result[:user]).to include('id' => user.id, 'email' => user.email, 'role' => user.role)
      end

      it 'creates a refresh token in the database' do
        expect { service.call }.to change(RefreshToken, :count).by(1)

        refresh_token = RefreshToken.last
        expect(refresh_token.user).to eq(user)
        expect(refresh_token.token).to be_present
        expect(refresh_token.expires_at).to be_within(1.minute).of(30.days.from_now)
      end

      it 'generates a valid JWT token' do
        result = service.call

        decoded = JWT.decode(result[:token], ENV.fetch('SECRET_KEY_BASE', nil))
        expect(decoded.first['user_id']).to eq(user.id)
        expect(decoded.first['exp']).to be_within(1.hour).of(24.hours.from_now.to_i)
      end
    end

    context 'with invalid password' do
      let(:password) { 'wrongpassword' }

      it 'returns error for invalid credentials' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.invalid_credentials'))
      end

      it 'does not create a refresh token' do
        expect { service.call }.not_to change(RefreshToken, :count)
      end
    end

    context 'with non-existent email' do
      let(:email) { 'nonexistent@example.com' }

      it 'returns error for invalid credentials' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.invalid_credentials'))
      end

      it 'does not create a refresh token' do
        expect { service.call }.not_to change(RefreshToken, :count)
      end
    end

    context 'with inactive user' do
      let(:email) { inactive_user.email }

      it 'returns error for inactive account' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.account_inactive'))
      end

      it 'does not create a refresh token' do
        expect { service.call }.not_to change(RefreshToken, :count)
      end
    end

    context 'with case-insensitive email' do
      let(:email) { 'USER@EXAMPLE.COM' }

      it 'authenticates successfully' do
        user # force user creation before service call
        result = service.call

        expect(result[:success]).to be true
        expect(result[:user]['id']).to eq(user.id)
      end
    end

    context 'with email containing whitespace' do
      let(:email) { '  user@example.com  ' }

      it 'authenticates successfully after trimming' do
        user # force user creation before service call
        result = service.call

        expect(result[:success]).to be true
        expect(result[:user]['id']).to eq(user.id)
      end
    end

    context 'when refresh token creation fails' do
      before do
        expect(RefreshToken).to receive(:transaction).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('auth.invalid_credentials')) # Since transaction fails, it falls back to invalid credentials
      end
    end
  end
end
