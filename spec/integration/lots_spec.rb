require 'swagger_helper'

RSpec.describe 'Api::V1::LotsController', type: :request do
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
      price_per_square_foot: 120.0,
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

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/projects/{project_id}/lots' do
    get 'List lots' do
      tags 'Lots'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'Project ID'

      response '200', 'List lots successfully' do
        let(:project_id) { project.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['lots']).to be_an(Array)
          expect(data['lots'].first['name']).to eq(lot.name)
        end
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{id}' do
    get 'Retrieve lot details' do
      tags 'Lots'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'Project ID'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'Lot ID'

      response '200', 'Lot retrieved successfully' do
        let(:project_id) { project.id }
        let(:id) { lot.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(lot.id)
          expect(data['name']).to eq(lot.name)
        end
      end

      response '404', 'Lot not found' do
        let(:project_id) { project.id }
        let(:id) { -1 }

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots' do
    post 'Create a lot' do
      tags 'Lots'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :lot, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          length: { type: :integer },
          width: { type: :integer },
          price: { type: :number }
        },
        required: ['name', 'length', 'width', 'price']
      }

      response '201', 'Lot created' do
        let(:project_id) { project.id }
        let(:lot_params) do # ✅ Renamed from `lot` to `lot_params`
          {
            name: 'Lote 2',
            length: 60,
            width: 30,
            price: 12000
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{id}' do
    put 'Update a lot' do
      tags 'Lots'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true, description: 'Lot ID'
      parameter name: :lot, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          length: { type: :integer },
          width: { type: :integer },
          price: { type: :number }
        }
      }

      response '200', 'Lot updated' do
        let(:project_id) { project.id }
        let(:id) { lot.id }
        let(:lot_params) do # ✅ Renamed
          {
            name: 'Lote Actualizado',
            length: 55,
            width: 35,
            price: 15000
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{id}' do
    delete 'Delete a lot' do
      tags 'Lots'
      security [bearerAuth: []]

      parameter name: :project_id, in: :path, type: :integer, required: true
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Lot deleted' do
        let(:project_id) { project.id }
        let(:id) { lot.id }

        run_test!
      end

      response '404', 'Lot not found' do
        let(:project_id) { project.id }
        let(:id) { -1 }

        run_test!
      end
    end
  end
end
