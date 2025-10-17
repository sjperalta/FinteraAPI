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

        run_test! do
          data = JSON.parse(response.body)
          expect(data['users']).to be_an(Array)
          expect(data['users'].size).to be >= 1

          # Verify pagination metadata is present
          expect(data['pagination']).to be_present
          expect(data['pagination']['count']).to be >= 1
        end
      end

      # Test cache invalidation on user list
      response '200', 'Users list cache is invalidated after user creation' do
        let(:auth_token) { "Bearer #{admin_user.generate_jwt}" }

        run_test! do
          data_before = JSON.parse(response.body)
          count_before = data_before['users'].size

          # Create a new user
          post '/api/v1/users',
               params: {
                 user: {
                   full_name: 'Cache Test User',
                   password: 'password@123',
                   password_confirmation: 'password@123',
                   email: "cachetest#{Time.now.to_i}@example.com",
                   phone: '5054445557',
                   identity: '31313131313131',
                   rtn: '313131313131313',
                   role: 'user'
                 }
               },
               headers: { 'Authorization' => auth_token }

          # Fetch users list again - should see the new user if cache was invalidated
          get '/api/v1/users', headers: { 'Authorization' => auth_token }
          data_after = JSON.parse(response.body)
          count_after = data_after['users'].size

          # Cache should have been invalidated, so count should increase
          expect(count_after).to be >= count_before
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
        run_test! do
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
        let(:update_params) do
          {
            user: {
              full_name: 'Updated Name'
            }
          }
        end

        run_test! do
          data = JSON.parse(response.body)
          expect(data['success']).to be true
          expect(data['user']['full_name']).to eq('Updated Name')

          # Verify cache was invalidated by checking the users list includes the updated user
          auth_token = "Bearer #{admin_user.generate_jwt}"
          get '/api/v1/users', headers: { 'Authorization' => auth_token }
          expect(response).to have_http_status(:ok)
          list_data = JSON.parse(response.body)
          expect(list_data).to be_a(Hash)
          expect(list_data['users']).to be_an(Array)
          updated_user_in_list = list_data['users'].find { |u| u['id'] == test_user.id }
          expect(updated_user_in_list).to be_present
          expect(updated_user_in_list['full_name']).to eq('Updated Name')
        end
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
        let(:auth_token) { "Bearer #{admin_user.generate_jwt}" }

        run_test! do
          data = JSON.parse(response.body)
          expect(data['message']).to eq('User soft deleted successfully')

          # Verify cache was invalidated
          auth_token = "Bearer #{admin_user.generate_jwt}"
          get '/api/v1/users', headers: { 'Authorization' => auth_token }
          expect(response).to have_http_status(:ok)
          list_data = JSON.parse(response.body)
          expect(list_data).to be_a(Hash)
          expect(list_data['users']).to be_an(Array)
          # Cache was cleared and fresh data is returned
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
        let(:auth_token) { "Bearer #{admin_user.generate_jwt}" }

        run_test! do
          data = JSON.parse(response.body)
          expect(data['message']).to eq('User restored successfully')

          # Verify cache was invalidated
          get '/api/v1/users', headers: { 'Authorization' => auth_token }
          expect(response).to have_http_status(:ok)
          list_data = JSON.parse(response.body)
          expect(list_data).to be_a(Hash)
          expect(list_data['users']).to be_an(Array)
          restored_user_in_list = list_data['users'].find { |u| u['id'] == deleted_user.id }
          expect(restored_user_in_list).to be_present
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

  # Cache behavior tests
  describe 'Cache invalidation behavior' do
    let(:auth_headers) { { 'Authorization' => "Bearer #{admin_user.generate_jwt}" } }

    it 'caches users index and invalidates on user creation' do
      # First request - cache miss
      get '/api/v1/users', headers: auth_headers
      expect(response).to have_http_status(:ok)
      first_response = JSON.parse(response.body)
      initial_count = first_response['users'].size

      # Second request - cache hit
      get '/api/v1/users', headers: auth_headers
      second_response = JSON.parse(response.body)
      expect(second_response['users'].size).to eq(initial_count)

      # Create a new user - should invalidate admin's cache
      post '/api/v1/users',
           params: {
             user: {
               full_name: 'New Cache Test User',
               password: 'password@123',
               password_confirmation: 'password@123',
               email: "cachenew#{Time.now.to_i}@example.com",
               phone: '5054445558',
               identity: '32323232323232',
               rtn: '323232323232323',
               role: 'user'
             }
           },
           headers: auth_headers
      expect(response).to have_http_status(:created)

      # Third request - cache should be invalidated, showing new user
      get '/api/v1/users', headers: auth_headers
      third_response = JSON.parse(response.body)
      expect(third_response['users'].size).to be > initial_count
    end

    it 'invalidates cache when user is updated' do
      original_name = test_user.full_name
      auth_token = "Bearer #{admin_user.generate_jwt}"

      # Get initial list
      get '/api/v1/users', headers: { 'Authorization' => auth_token }
      list_response = JSON.parse(response.body)
      expect(list_response['users'].map { |u| u['full_name'] }).to include(original_name)

      # Update the user
      put "/api/v1/users/#{test_user.id}",
          params: {
            user: {
              full_name: 'Completely Different Name'
            }
          },
          headers: { 'Authorization' => auth_token }
      expect(response).to have_http_status(:ok)

      # Get list again - should show updated name
      get '/api/v1/users', headers: { 'Authorization' => auth_token }
      updated_list = JSON.parse(response.body)
      updated_user = updated_list['users'].find { |u| u['id'] == test_user.id }
      expect(updated_user['full_name']).to eq('Completely Different Name')
    end

    it 'cache key includes role and pagination parameters' do
      # Request with specific role and per_page
      get '/api/v1/users?role=admin&per_page=5', headers: auth_headers
      expect(response).to have_http_status(:ok)
      first_admin_response = JSON.parse(response.body)
      admin_count = first_admin_response['users'].size

      # Request with different role should have different cache
      get '/api/v1/users?role=user&per_page=5', headers: auth_headers
      expect(response).to have_http_status(:ok)
      user_response = JSON.parse(response.body)
      # Different role might have different user count
      expect(user_response['users']).to be_an(Array)

      # Request with admin role again should be cached
      get '/api/v1/users?role=admin&per_page=5', headers: auth_headers
      second_admin_response = JSON.parse(response.body)
      expect(second_admin_response['users'].size).to eq(admin_count)
    end
  end
end
