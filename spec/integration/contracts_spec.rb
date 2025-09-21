require 'swagger_helper'

RSpec.describe 'Api::V1::ContractsController', type: :request do
  let!(:user) do
    User.create!(
      id: 1,
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
      price: 10000,
      project: project
    )
  end

  let!(:contract) do
    Contract.create!(
      lot: lot,
      applicant_user_id: 1,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 2000.0,
      down_payment: 5000.0
    )
  end

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  before do
    Rails.application.routes.default_url_options[:host] = 'http://localhost:3000'
  end

  path '/api/v1/contracts' do
    get 'List contracts' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'List contracts successfully' do
        let(:Authorization) { "Bearer #{user.reload.generate_jwt}" }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['contracts']).to be_an(Array)
        end
      end
    end
  end

  # path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}' do

  #   get 'Retrieve contract details' do
  #     tags 'Contracts'
  #     consumes 'application/json'
  #     produces 'application/json'
  #     security [bearerAuth: []]

  #     parameter name: :project_id, in: :path, type: :integer, required: true, description: 'Project ID'
  #     parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'Lot ID'
  #     parameter name: :id, in: :path, type: :integer, required: true, description: 'Contract ID'

  #     response '200', 'Contract retrieved successfully' do
  #       let(:Authorization) { "Bearer #{user.reload.generate_jwt}" }
  #       let(:project_id) { project.id }
  #       let(:lot_id) { lot.id }
  #       let(:id) { contract.id }

  #       run_test! do |response|
  #         data = JSON.parse(response.body)
  #         expect(data['id']).to eq(contract.id)
  #       end
  #     end

  #     response '404', 'Contract not found' do
  #       let(:project_id) { project.id }
  #       let(:lot_id) { lot.id }
  #       let(:id) { -1 }

  #       run_test!
  #     end
  #   end
  # end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts' do
    post 'Create a contract' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :lot_id, in: :path, type: :integer, required: true
      parameter name: :contract_request, in: :body, required: true, schema: {
        type: :object,
        properties: {
          contract:
          {
              payment_term: { type: :integer },
              financing_type: { type: :string },
              applicant_user_id: { type: :integer },
              reserve_amount: { type: :number },
              down_payment: { type: :number }
          },
          user:
          {
            phone: { type: :string },
            full_name: { type: :string },
            identity: { type: :string },
            rtn: { type: :string },
            email: { type: :string }
          }
        },
        required: ['contract', 'user']
      }

      response '201', 'Contract created' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_request) do
          {
            contract: {
              payment_term: 12,
              financing_type: 'direct',
              applicant_user_id: user.id,
              reserve_amount: 2000.00,
              down_payment: 5000.00
            },
            user: {
              full_name: "John Doe",
              phone: "123456789",
              identity: "987654321",
              rtn: "1234567890",
              email: "john.doe@example.com"
            }
          }
        end

        run_test!
      end

      response '422', 'Validation error' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_request) do
          {
            contract: {
              payment_term: nil,
              financing_type: nil,
              applicant_user_id: nil,
              reserve_amount: 2000.00,
              down_payment: 5000.00
            },
            user: {
              full_name: "John Doe",
              phone: "123456789",
              identity: "987654321",
              rtn: "1234567890",
              email: "john.doe@example.com"
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/approve' do
    post 'Approve a contract' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :lot_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Contract approved' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/reject' do
    post 'Reject a contract' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :lot_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Contract rejected' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/cancel' do
    let!(:contract) do
      Contract.create!(
        lot: lot,
        status: 'rejected',
        applicant_user_id: 1,
        payment_term: 12,
        financing_type: 'direct',
        reserve_amount: 2000.0,
        down_payment: 5000.0
      )
    end

    post 'Cancel a contract' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :lot_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Contract canceled' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end
    end
  end
end
