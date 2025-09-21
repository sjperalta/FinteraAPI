require 'swagger_helper'

RSpec.describe 'Api::V1::PaymentsController', type: :request do
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
      applicant_user_id: user.id,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 2000.00,
      down_payment: 5000.00,
      balance: 15000.00,
      currency: 'USD',
      status: 'pending'
    )
  end

  let!(:payment) do
    Payment.create!(
      contract: contract,
      description: 'First payment',
      amount: 500.00,
      interest_amount: 50.00,
      status: 'pending',
      due_date: Date.today + 30.days
    )
  end

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/payments' do
    get 'List payments' do
      tags 'Payments'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      response '200', 'List payments successfully' do
        let(:Authorization) { "Bearer #{user.reload.generate_jwt}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['payments']).to be_an(Array)
          expect(data['payments'].first['id']).to eq(payment.id)
        end
      end
    end
  end

  path '/api/v1/payments/{id}' do
    get 'Retrieve payment details' do
      tags 'Payments'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Payment ID'

      response '200', 'Payment retrieved successfully' do
        let(:id) { payment.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.id)
          expect(data['amount']).to eq(payment.amount.to_s)
        end
      end

      response '404', 'Payment not found' do
        let(:id) { -1 }
        run_test!
      end
    end
  end

  path '/api/v1/payments/{id}/approve' do
    post 'Approve a payment' do
      tags 'Payments'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Payment approved' do
        let(:id) { payment.id }

        before do
          allow_any_instance_of(Payments::ApprovePaymentService).to receive(:call).and_return({ success: true, payment: payment })
        end

        run_test!
      end

      response '422', 'Payment cannot be approved' do
        let(:id) { payment.id }

        before do
          allow_any_instance_of(Payments::ApprovePaymentService).to receive(:call).and_return({ success: false, message: 'Approval failed' })
        end

        run_test!
      end
    end
  end

  path '/api/v1/payments/{id}/reject' do
    post 'Reject a payment' do
      tags 'Payments'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'Payment rejected' do
        let(:id) { payment.id }

        before do
          allow_any_instance_of(Payment).to receive(:may_reject?).and_return(true)
          allow_any_instance_of(Payment).to receive(:reject!).and_return(true)
        end

        run_test!
      end

      response '422', 'Payment cannot be rejected' do
        let(:id) { payment.id }

        before do
          allow_any_instance_of(Payment).to receive(:may_reject?).and_return(false)
        end

        run_test!
      end
    end
  end

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/payments/{id}/upload_receipt' do
    post 'Upload payment receipt' do
      tags 'Payments'
      security [bearerAuth: []]
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :receipt, in: :formData, type: :file, required: true, description: 'Receipt file to upload'

      response '200', 'Receipt uploaded successfully' do
        let(:id) { payment.id }
        let(:receipt) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/receipt.pdf'), 'pdf') }

        before do
          allow_any_instance_of(Payment).to receive(:may_submit?).and_return(true)
          allow_any_instance_of(Payment).to receive(:submit!).and_return(true)
        end

        run_test!
      end

      response '422', 'Receipt file is required' do
        let(:id) { payment.id }
        let(:receipt) { nil }

        run_test!
      end

      response '422', 'Failed to process payment submission' do
        let(:id) { payment.id }
        let(:receipt) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/receipt.pdf'), 'pdf') }

        before do
          allow_any_instance_of(Payment).to receive(:may_submit?).and_return(false)
        end

        run_test!
      end
    end
  end
end
