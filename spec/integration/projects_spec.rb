require 'swagger_helper'

RSpec.describe 'Api::V1::ProjectsController', type: :request do
  let!(:admin_user) do
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
  let(:Authorization) { "Bearer #{admin_user.generate_jwt}" }

  path '/api/v1/projects' do
    get 'List all projects' do
      tags 'Projects'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      response '200', 'Projects retrieved successfully' do
        let!(:projects) { [project] }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['projects']).to be_an(Array)
          expect(data['projects'].size).to eq(1)
        end
      end
    end

    post 'Create a new project' do
      tags 'Projects'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :project, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          project_type: { type: :string },
          address: { type: :string },
          lot_count: { type: :integer },
          price_per_square_unit: { type: :number },
          measurement_unit: { type: :string },
          interest_rate: { type: :number },
          commission_rate: { type: :number },
          delivery_date: { type: :string, format: :date }
        },
  required: ['name', 'description', 'project_type', 'address', 'lot_count', 'price_per_square_unit', 'measurement_unit']
      }

      response '201', 'Project created successfully' do
        let(:project) do
          {
            name: 'New Project',
            description: 'Project description',
            project_type: 'Residential',
            address: '123 Main St',
            lot_count: 10,
            price_per_square_unit: 150.0,
            measurement_unit: 'm2',
            interest_rate: 5.5,
            commission_rate: 2.0,
            delivery_date: Date.today.to_s
          }
        end
        run_test!
      end

      response '422', 'Validation error' do
        let(:project) { { name: '', description: '' } }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}' do
    get 'Retrieve a project' do
      tags 'Projects'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Project ID'

      response '200', 'Project retrieved successfully' do
        let(:id) { project.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(project.id)
          expect(data['name']).to eq(project.name)
        end
      end

      response '404', 'Project not found' do
        let(:id) { -1 }
        run_test!
      end
    end

    put 'Update a project' do
      tags 'Projects'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Project ID'
      parameter name: :project, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          project_type: { type: :string },
          address: { type: :string },
          lot_count: { type: :integer },
          price_per_square_unit: { type: :number },
          measurement_unit: { type: :string },
          interest_rate: { type: :number },
          commission_rate: { type: :number },
          delivery_date: { type: :string, format: :date }
        }
      }

      response '200', 'Project updated successfully' do
        let(:id) { project.id }
        let(:update_params) { { name: 'Updated Project Name' } }

        run_test!
      end

      # TODO: improve service logic to avoid blank parameters
      # response '422', 'Validation error' do
      #   let(:id) { project.id }
      #   let(:update_params) { { name: '' } }

      #   run_test!
      # end
    end

    delete 'Delete a project' do
      tags 'Projects'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Project deleted successfully' do
        let(:id) { project.id }
        run_test!
      end

      response '404', 'Project not found' do
        let(:id) { -1 }
        run_test!
      end
    end
  end
end
