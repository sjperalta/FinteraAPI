require 'swagger_helper'

RSpec.describe Api::V1::ProjectsController, type: :request do
  # Creamos manualmente un usuario que será utilizado para los tests
  let(:user) do
    User.create!(
      email: 'user@example.com',
      password: 'password123',
      role: 'admin',
      confirmed_at: Time.now
    )
  end
  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  # Definimos un proyecto que será utilizado en las pruebas
  let(:project) do
    Project.create!(
      name: 'Proyecto 1',
      description: 'Descripción del proyecto 1',
      address: 'Dirección del proyecto 1',
      lot_count: 10,
      price_per_square_foot: 100.0,
      interest_rate: 5.0
    )
  end

  path '/api/v1/projects' do
    get 'Lista todos los proyectos' do
      tags 'Projects'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Proyectos listados exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }  # No se incluye el token JWT
        run_test!
      end
    end

    post 'Crea un nuevo proyecto' do
      tags 'Projects'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          address: { type: :string },
          lot_count: { type: :integer },
          price_per_square_foot: { type: :number },
          interest_rate: { type: :number }
        },
        required: ['name', 'description', 'address', 'lot_count', 'price_per_square_foot', 'interest_rate']
      }

      response '201', 'Proyecto creado exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project) do
          {
            name: 'Nuevo Proyecto',
            description: 'Descripción del nuevo proyecto',
            address: 'Nueva dirección',
            lot_count: 5,
            price_per_square_foot: 200.0,
            interest_rate: 4.5
          }
        end
        run_test!
      end

      response '422', 'Errores de validación' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project) do
          {
            name: nil,  # Campo faltante para provocar error
            description: 'Descripción del nuevo proyecto',
            address: 'Nueva dirección',
            lot_count: 5,
            price_per_square_foot: 200.0,
            interest_rate: 4.5
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/projects/{id}' do
    get 'Muestra un proyecto específico' do
      tags 'Projects'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del proyecto'

      response '200', 'Proyecto encontrado' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { project.id }
        run_test!
      end

      response '404', 'Proyecto no encontrado' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { 9999 }  # ID inexistente para forzar un 404
        run_test!
      end
    end

    put 'Actualiza un proyecto' do
      tags 'Projects'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :project, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          address: { type: :string },
          lot_count: { type: :integer },
          price_per_square_foot: { type: :number },
          interest_rate: { type: :number }
        }
      }

      response '200', 'Proyecto actualizado exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { project.id }
        let(:project) do
          {
            name: 'Proyecto actualizado',
            description: 'Descripción actualizada',
            address: 'Dirección actualizada'
          }
        end
        run_test!
      end

      response '422', 'Errores de validación' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { project.id }
        let(:project) do
          {
            name: nil,  # Provocando error
            description: 'Descripción actualizada',
            address: 'Dirección actualizada'
          }
        end
        run_test!
      end
    end

    delete 'Elimina un proyecto' do
      tags 'Projects'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del proyecto'

      response '200', 'Proyecto eliminado exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { project.id }
        run_test!
      end

      response '404', 'Proyecto no encontrado' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:id) { 9999 }  # ID inexistente para provocar error 404
        run_test!
      end
    end
  end
end
