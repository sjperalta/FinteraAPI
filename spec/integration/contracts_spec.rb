require 'swagger_helper'

RSpec.describe Api::V1::ContractsController, type: :request do
  # Creamos los registros necesarios manualmente sin FactoryBot

  let(:user) do
    User.create!(
      email: 'user@example.com',
      password: 'password123',
      role: 'admin',
      confirmed_at: Time.now
    )
  end

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

  let(:lot) do
    Lot.create!(
      name: 'Lote 1',
      length: 50,
      width: 50,
      price: 10000,
      project: project
    )
  end

  let(:contract) do
    Contract.create!(
      lot: lot,
      applicant_user_id: user.id,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 1000.0,
      down_payment: 5000.0
    )
  end

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts' do
    post 'Crea un contrato' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_request, in: :body, schema: {
        type: :object,
        properties: {
          payment_term: { type: :integer },
          financing_type: { type: :string },
          applicant_user_id: { type: :integer },
          reserve_amount: { type: :number },
          down_payment: { type: :number }
        },
        required: ['payment_term', 'financing_type', 'applicant_user_id', 'reserve_amount', 'down_payment']
      }

      response '201', 'Contrato creado' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_request) do
          {
            payment_term: 12,
            financing_type: 'direct',
            applicant_user_id: user.id,
            reserve_amount: 1000.00,
            down_payment: 5000.00
          }
        end

        run_test!
      end

      response '422', 'Errores de validación' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_request) do
          {
            payment_term: nil,  # Parámetro incorrecto para probar errores de validación
            financing_type: nil,
            applicant_user_id: nil,
            reserve_amount: nil,
            down_payment: nil
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/approve' do
    post 'Aprueba un contrato' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del contrato'

      response '200', 'Contrato aprobado' do
        let(:contract) do
          Contract.create!(
            lot: lot,
            applicant_user_id: user.id,
            payment_term: 12,
            financing_type: 'direct',
            reserve_amount: 1000.0,
            down_payment: 5000.0
          )
        end

        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end

      response '422', 'Errores de validación' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }
        before { allow_any_instance_of(Contracts::ApproveContractService).to receive(:call).and_return({ success: false, errors: ['Error al aprobar'] }) }

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/reject' do
    post 'Rechaza un contrato' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del contrato'

      response '200', 'Contrato rechazado' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end

      response '422', 'Errores de validación' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }
        before { allow_any_instance_of(Contracts::RejectContractService).to receive(:call).and_return({ success: false, errors: ['Error al rechazar'] }) }

        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{id}/cancel' do
    post 'Cancela un contrato' do
      tags 'Contracts'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del contrato'

      response '200', 'Contrato cancelado' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }

        run_test!
      end

      response '422', 'Errores de validación' do
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:id) { contract.id }
        before { allow_any_instance_of(Contracts::CancelContractService).to receive(:call).and_return({ success: false, errors: ['Error al cancelar'] }) }

        run_test!
      end
    end
  end
end
