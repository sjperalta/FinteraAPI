# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::AuthController', type: :request do
  let!(:user) do
    User.create!(
      email: 'user@example.com',
      password: 'password123',
      full_name: 'testing user',
      phone: '50449494442',
      identity: '40405005050505',
      rtn: '404050050505051',
      role: 'admin',
      confirmed_at: Time.now
    )
  end

  let(:valid_credentials) { { email: user.email, password: 'password123' } }
  let(:invalid_credentials) { { email: user.email, password: 'wrongpassword' } }
  let(:refresh_token) { RefreshToken.create!(user:, token: SecureRandom.hex) }
  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/auth/login' do
    post('User login') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response(200, 'Successful login') do
        let(:credentials) { valid_credentials }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).not_to be_nil
          expect(data['refresh_token']).not_to be_nil
          expect(data['user']['email']).to eq(user.email)
        end
      end

      response(401, 'Unauthorized') do
        let(:credentials) { invalid_credentials }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_present
        end
      end
    end
  end

  path '/api/v1/auth/logout' do
    post 'Logs out a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :refresh_token, in: :body, required: true, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: ['refresh_token']
      }

      response '200', 'Logged out successfully' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:refresh_token) do
          { refresh_token: RefreshToken.create!(user:, token: SecureRandom.hex, expires_at: DateTime.now).token }
        end

        run_test!
      end

      response '401', 'Invalid or missing token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:refresh_token) { 'invalid_refresh_token' }

        run_test!
      end
    end
  end

  path '/api/v1/auth/refresh' do
    post('Refresh token') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :refresh_request, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: %w[refresh_token]
      }

      response(200, 'Token refreshed successfully') do
        let(:refresh_request) { { refresh_token: 'valid_refresh_token' } }

        before do
          allow_any_instance_of(Api::V1::AuthController).to receive(:decode_token).and_return({ user_id: user.id,
                                                                                                exp: (Time.now + 1.hour).to_i })
          allow_any_instance_of(Api::V1::AuthController).to receive(:generate_token).and_return('new_access_token')
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to eq('new_access_token')
          expect(data['user']['email']).to eq(user.email)
        end
      end

      response(401, 'Invalid or expired refresh token') do
        let(:refresh_request) { { refresh_token: 'expired_token' } }

        before do
          allow_any_instance_of(Api::V1::AuthController).to receive(:decode_token).and_return(nil)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to eq(['Invalid or expired refresh token'])
        end
      end
    end
  end
end
