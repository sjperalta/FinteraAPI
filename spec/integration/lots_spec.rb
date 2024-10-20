# spec/integration/lots_spec.rb

require 'swagger_helper'

RSpec.describe Api::V1::LotsController, type: :request do
  let(:project) { Project.create!(name: 'Proyecto Ejemplo', description: 'Descripción del proyecto', address: 'Dirección', lot_count: 5, price_per_square_foot: 100, interest_rate: 5) }
  let(:lot) { project.lots.create!(name: 'Lote 1', length: 30, width: 20, price: 60000) }
  let(:Authorization) { "Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3Mjk1MzE2OTd9.TVYpQQUXl18wgkstip0NDwEH6YHy2BK8wyTS7wthiTI" }  # Aquí se coloca el token JWT válido para las pruebas

  path '/api/v1/projects/{project_id}/lots' do
    get 'Lista todos los lotes de un proyecto' do
      tags 'Lotes'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :string, description: 'ID del proyecto'

      response '200', 'Lotes listados correctamente' do
        let(:project_id) { project.id }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }
        let(:project_id) { project.id }
        run_test!
      end
    end

    post 'Crear un lote para un proyecto' do
      tags 'Lotes'
      consumes 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :string, description: 'ID del proyecto'
      parameter name: :lot, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          length: { type: :integer },
          width: { type: :integer },
          price: { type: :number }
        },
        required: ['name', 'length', 'width', 'price']
      }

      response '201', 'Lote creado exitosamente' do
        let(:project_id) { project.id }
        let(:lot) { { project_id: project_id, name: 'Lote 2', length: 25, width: 20, price: 50000 } }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }
        let(:project_id) { project.id }
        let(:lot) { { project_id: project_id, name: 'Lote 2', length: 25, width: 20, price: 50000 } }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{id}' do
    get 'Mostrar un lote específico' do
      tags 'Lotes'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :string, description: 'ID del proyecto'
      parameter name: :id, in: :path, type: :string, description: 'ID del lote'

      response '200', 'Lote mostrado correctamente' do
        let(:project_id) { project.id }
        let(:id) { lot.id }
        run_test!
      end

      response '404', 'Lote no encontrado' do
        let(:project_id) { project.id }
        let(:id) { 'non_existing_id' }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }
        let(:project_id) { project.id }
        let(:id) { lot.id }
        run_test!
      end
    end

    put 'Actualizar un lote' do
      tags 'Lotes'
      consumes 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :string, description: 'ID del proyecto'
      parameter name: :id, in: :path, type: :string, description: 'ID del lote'
      parameter name: :lot, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          length: { type: :integer },
          width: { type: :integer },
          price: { type: :number }
        },
        required: ['name', 'length', 'width', 'price']
      }

      response '200', 'Lote actualizado exitosamente' do
        let(:project_id) { project.id }
        let(:id) { lot.id }
        let(:lot) { { name: 'Lote Actualizado', length: 40, width: 30, price: 120000 } }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }
        let(:project_id) { project.id }
        let(:id) { lot.id }
        let(:lot) { { name: 'Lote Actualizado', length: 40, width: 30, price: 120000 } }
        run_test!
      end
    end

    delete 'Eliminar un lote' do
      tags 'Lotes'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :string, description: 'ID del proyecto'
      parameter name: :id, in: :path, type: :string, description: 'ID del lote'

      response '200', 'Lote eliminado exitosamente' do
        let(:project_id) { project.id }
        let(:id) { lot.id }
        run_test!
      end

      response '404', 'Lote no encontrado' do
        let(:project_id) { project.id }
        let(:id) { 'non_existing_id' }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }
        let(:project_id) { project.id }
        let(:id) { lot.id }
        run_test!
      end
    end
  end
end
