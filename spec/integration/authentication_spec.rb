# spec/integration/authentication_spec.rb

require 'swagger_helper'

RSpec.describe 'Autenticación', type: :request do
  path '/api/v1/auth/login' do
    post 'Iniciar sesión' do
      tags 'Autenticación'
      consumes 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: ['email', 'password']
      }

      response '200', 'Inicio de sesión exitoso' do
        let!(:user) { User.create!(email: 'user@example.com', password: 'password123', password_confirmation: 'password123', role: 'admin', confirmed_at: Time.now) }
        let(:credentials) { { email: 'user@example.com', password: 'password123' } }
        run_test!
      end

      response '401', 'Credenciales inválidas' do
        let(:credentials) { { email: 'user@example.com', password: 'wrongpassword' } }
        run_test!
      end
    end
  end
end
