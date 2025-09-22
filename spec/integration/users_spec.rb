# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::UsersController', type: :request do
  let!(:admin_user) do
    User.create(
      email: 'admin@example.com',
      full_name: 'Admin User',
      phone: '50449494442',
      identity: '40405005050505',
      rtn: '404050050505051',
      role: 'admin',
      password: 'password123', # ✅ Password is required
      password_confirmation: 'password123',
      confirmed_at: Time.now
    )
  end
  let!(:test_user) do
    User.create!(
      full_name: 'New User',
      email: 'newuser@example.com',
      phone: '5054445555',
      identity: '20202020202020',
      rtn: '202020202020202',
      role: 'user',
      password: 'password123', # ✅ Password is required
      password_confirmation: 'password123',
      confirmed_at: Time.now # ✅ Bypass email confirmation
    )
  end
  let!(:project) do
    Project.create!(
      name: 'Proyecto 1',
      description: 'Descripción del proyecto',
      address: 'Dirección 1',
      lot_count: 5,
      price_per_square_unit: 120.0,
      measurement_unit: 'm2',
      interest_rate: 5.5
    )
  end
  let!(:lot) do
    Lot.create!(
      name: 'Lote 1',
      length: 50,
      width: 40,
      price: 10_000,
      project:
    )
  end
  let!(:contract) do
    Contract.create!(
      lot:,
      applicant_user_id: test_user.id, # Use the created user
      creator_id: admin_user.id,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 2000.00,
      down_payment: 5000.00,
      balance: 15_000.00,
      currency: 'USD',
      status: 'pending'
    )
  end
  let!(:payment) do
    Payment.create!(
      contract:,
      description: 'First payment',
      amount: 500.00,
      interest_amount: 50.00,
      status: 'pending',
      due_date: Date.today + 30.days
    )
  end

  let(:Authorization) { "Bearer #{admin_user.generate_jwt}" }
  path '/api/v1/users' do
    get 'List all users' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      response '200', 'Users retrieved successfully' do
        before { [admin_user] }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['users']).to be_an(Array)
          expect(data['users'].size).to be >= 1
        end
      end
    end

    post 'Create a new user' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, required: true, schema: {
        type: :object,
        properties: {
          full_name: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string },
          email: { type: :string },
          phone: { type: :string },
          identity: { type: :string },
          rtn: { type: :string },
          role: { type: :string }
        },
        required: %w[full_name email phone identity rtn role password password_confirmation]
      }

      let(:Authorization) { "Bearer #{admin_user.generate_jwt}" }

      response '201', 'User created successfully' do
        let(:user) do
          {
            user: {
              full_name: 'Created User',
              password: 'password@123',
              password_confirmation: 'password@123',
              email: 'createduser@example.com',
              phone: '5054445556',
              identity: '30303030303030',
              rtn: '303030303030303',
              role: 'user'
            }
          }
        end

        run_test!
      end

      response '422', 'Validation error' do
        let(:user) { { user: { full_name: '', email: '' } } }

        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    get 'Retrieve a user' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'User ID'

      response '200', 'User retrieved successfully' do
        let(:id) { test_user.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(test_user.id)
          expect(data['email']).to eq(test_user.email)
        end
      end

      response '404', 'User not found' do
        let(:id) { -1 }
        run_test!
      end
    end

    put 'Update a user' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'User ID'
      parameter name: :update_params, in: :body, required: true, schema: {
        type: :object,
        properties: {
          full_name: { type: :string },
          phone: { type: :string },
          identity: { type: :string },
          rtn: { type: :string }
        }
      }

      response '200', 'User updated successfully' do
        let(:id) { test_user.id }
        let(:update_params) { { full_name: 'Updated Name' } }
        run_test!
      end

      response '422', 'Validation error' do
        let(:id) { test_user.id }
        let(:update_params) { { full_name: '' } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    delete 'Soft delete a user' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'User ID'

      response '200', 'User soft deleted successfully' do
        let(:id) { test_user.id }
        let(:Authorization) { "Bearer #{admin_user.generate_jwt}" } # Admin user

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('User soft deleted successfully')
        end
      end

      response '403', 'Not authorized' do
        let(:id) { test_user.id }
        let(:Authorization) { "Bearer #{test_user.generate_jwt}" } # Normal user should not have access

        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/restore' do
    post 'Restore a soft deleted user' do
      tags 'Users'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'User ID'

      response '200', 'User restored successfully' do
        let!(:deleted_user) do
          u = User.create(
            email: 'to_restore@example.com',
            password: 'password123',
            full_name: 'To Restore',
            phone: '50449990011',
            identity: '90909090909090',
            rtn: '909090909090909',
            role: 'user',
            confirmed_at: Time.now
          )
          u.discard
          u
        end

        let(:id) { deleted_user.id }
        let(:Authorization) { "Bearer #{admin_user.generate_jwt}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('User restored successfully')
        end
      end

      response '403', 'Not authorized' do
        let!(:user) do
          User.create(
            email: 'user@example.com',
            password: 'password123',
            full_name: 'Test User',
            phone: '50449992211',
            identity: '10101010101010',
            rtn: '101010101010101',
            role: 'user',
            confirmed_at: Time.now
          )
        end
        let(:id) { test_user.id }
        let(:Authorization) { "Bearer #{test_user.generate_jwt}" } # Normal user

        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/contracts' do
    get 'Retrieve user contracts' do
      tags 'Users'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Contracts retrieved' do
        let(:id) { test_user.id }
        run_test!
      end

      response '404', 'User not found' do
        let(:id) { -1 }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/payments' do
    get 'Retrieve user payments' do
      tags 'Users'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Payments retrieved' do
        let(:id) { test_user.id }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/summary' do
    get 'Retrieve user summary' do
      tags 'Users'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'User summary retrieved' do
        let(:id) { test_user.id }
        run_test!
      end
    end
  end
end
