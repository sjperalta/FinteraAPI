require 'swagger_helper'

RSpec.describe Api::V1::PaymentsController, type: :request do
  # Crear usuario admin para los tests
  let!(:user) { User.create!(email: 'admin@example.com', password: 'password123', role: 'admin', confirmed_at: Time.now) }
  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  # Crear datos asociados al contrato
  let!(:project) { Project.create!(name: 'Proyecto 1', description: 'Descripción del proyecto', address: 'Dirección', lot_count: 5, price_per_square_foot: 200.0, interest_rate: 5.0) }
  let!(:lot) { Lot.create!(name: 'Lote 1', length: 50, width: 50, price: 10000, project: project) }
  let!(:contract) { Contract.create!(lot: lot, applicant_user_id: user.id, payment_term: 12, financing_type: 'direct', reserve_amount: 1000, down_payment: 5000) }
  let!(:payment) { Payment.create!(contract: contract, amount: 500, due_date: Date.today + 30.days, status: 'pending') }

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{contract_id}/payments' do
    get 'Lista todos los pagos del contrato' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_id, in: :path, type: :integer, required: true, description: 'ID del contrato'

      response '200', 'Lista de pagos obtenida exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        run_test!
      end

      response '401', 'No autorizado' do
        let(:Authorization) { nil }  # Sin token JWT
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{contract_id}/payments/{id}' do
    get 'Muestra un pago específico' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_id, in: :path, type: :integer, required: true, description: 'ID del contrato'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del pago'

      response '200', 'Pago encontrado' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        run_test!
      end

      response '404', 'Pago no encontrado' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { 9999 }  # ID inexistente para provocar error
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{contract_id}/payments/{id}/approve' do
    post 'Aprueba un pago' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_id, in: :path, type: :integer, required: true, description: 'ID del contrato'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del pago'

      response '200', 'Pago aprobado exitosamente' do
        let!(:contract) { Contract.create!(lot: lot, applicant_user_id: user.id, payment_term: 12, financing_type: 'direct', reserve_amount: 1000, down_payment: 5000) }
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        run_test!
      end

      response '422', 'Error al aprobar el pago' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        before { allow_any_instance_of(Payments::ApprovePaymentService).to receive(:call).and_return(false) }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{contract_id}/payments/{id}/reject' do
    post 'Rechaza un pago' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_id, in: :path, type: :integer, required: true, description: 'ID del contrato'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del pago'

      response '200', 'Pago rechazado exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        run_test!
      end

      response '422', 'Error al rechazar el pago' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        before { allow_any_instance_of(Payments::RejectPaymentService).to receive(:call).and_return(false) }
        run_test!
      end
    end
  end

  path '/api/v1/projects/{project_id}/lots/{lot_id}/contracts/{contract_id}/payments/{id}/upload_receipt' do
    post 'Sube un comprobante de pago' do
      tags 'Payments'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :project_id, in: :path, type: :integer, required: true, description: 'ID del proyecto'
      parameter name: :lot_id, in: :path, type: :integer, required: true, description: 'ID del lote'
      parameter name: :contract_id, in: :path, type: :integer, required: true, description: 'ID del contrato'
      parameter name: :id, in: :path, type: :integer, required: true, description: 'ID del pago'
      parameter name: :receipt, in: :formData, type: :file, required: true, description: 'Archivo del comprobante'

      response '200', 'Comprobante subido exitosamente' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        let(:receipt) { fixture_file_upload(Rails.root.join('spec/fixtures/receipt.pdf'), 'application/pdf') }
        run_test!
      end

      response '422', 'Error al subir el comprobante' do
        let(:Authorization) { "Bearer #{user.generate_jwt}" }
        let(:project_id) { project.id }
        let(:lot_id) { lot.id }
        let(:contract_id) { contract.id }
        let(:id) { payment.id }
        let(:receipt) { nil }  # Comprobante faltante
        run_test!
      end
    end
  end
end
