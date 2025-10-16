# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::UploadReceiptService do
  let(:user) do
    user = User.new(
      email: 'test@example.com',
      full_name: 'Test User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '1234567890',
      identity: '123456789',
      rtn: '123456789',
      role: 'user',
      status: 'active',
      locale: 'es'
    )
    allow(user).to receive(:id).and_return(1)
    user
  end

  let(:contract) do
    project = Project.new(
      name: 'Test Project',
      description: 'Test',
      address: 'Test Address',
      price_per_square_unit: 100.0,
      interest_rate: 5.0,
      commission_rate: 10.0,
      measurement_unit: 'm2'
    )
    lot = Lot.new(
      project:,
      name: 'Lot 1',
      length: 10.0,
      width: 20.0,
      status: 'available'
    )
    contract = Contract.new(
      lot:,
      applicant_user: user,
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 1000.0,
      down_payment: 5000.0,
      active: true,
      status: 'pending'
    )
    allow(contract).to receive(:applicant_user_id).and_return(1)
    contract
  end

  let(:payment) do
    payment = Payment.new(
      contract:,
      amount: 1000.0,
      status: 'pending',
      due_date: 1.month.from_now
    )
    allow(payment).to receive(:may_submit?).and_return(true)
    allow(payment).to receive(:submit!)
    allow(payment).to receive(:update!)
    payment
  end

  let(:receipt) { double('receipt', present?: true) }
  let(:paid_amount) { 1000.0 }
  let(:service) do
    described_class.new(
      payment:,
      receipt:,
      user:,
      paid_amount:
    )
  end

  describe '#call' do
    context 'when upload is successful' do
      before do
        allow(payment).to receive(:document).and_return(double('document').as_null_object)
        allow(payment).to receive(:may_submit?).and_return(true)
        allow(payment).to receive(:submit!)
        allow(payment).to receive(:update!)
        allow_any_instance_of(described_class).to receive(:notify_admins)
        allow(NotifyAdminPaymentReceiptJob).to receive(:perform_later)
      end

      it 'attaches the receipt' do
        expect(payment.document).to receive(:attach).with(receipt)

        service.call
      end

      it 'updates payment attributes' do
        expect(payment).to receive(:update!).with(hash_including(payment_date: Time.zone.today,
                                                                 paid_amount:))

        service.call
      end

      it 'submits the payment' do
        expect(payment).to receive(:submit!)

        service.call
      end

      it 'sends notifications' do
        expect_any_instance_of(described_class).to receive(:notify_admins).with(
          title: 'Pago Actualizado',
          message: "Has recibido un pago por #{payment.amount}, Contrato ##{payment.contract.id}",
          notification_type: 'payment_upload'
        )
        expect(NotifyAdminPaymentReceiptJob).to receive(:perform_later).with(payment)

        service.call
      end

      it 'returns success result' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:payment]).to eq(payment)
      end
    end

    context 'when validation fails' do
      context 'when receipt is not present' do
        let(:receipt) { double('receipt', present?: false) }

        it 'returns failure with error message' do
          result = service.call

          expect(result[:success]).to be false
          expect(result[:errors]).to include('El comprobante es requerido.')
        end
      end

      context 'when user is not authorized' do
        let(:unauthorized_user) do
          user = User.new(
            email: 'unauthorized@example.com',
            full_name: 'Unauthorized User',
            password: 'password123',
            password_confirmation: 'password123',
            phone: '0987654321',
            identity: '987654321',
            rtn: '987654321',
            role: 'user',
            status: 'active',
            locale: 'es'
          )
          allow(user).to receive(:id).and_return(2)
          user
        end
        let(:service) do
          described_class.new(
            payment:,
            receipt:,
            user: unauthorized_user,
            paid_amount:
          )
        end

        it 'returns failure with error message' do
          result = service.call

          expect(result[:success]).to be false
          expect(result[:errors]).to include('El usuario no está autorizado para subir este comprobante.')
        end
      end

      context 'when payment is already paid' do
        let(:payment) do
          Payment.new(
            contract:,
            amount: 1000.0,
            status: 'paid',
            due_date: 1.month.from_now
          )
        end

        it 'returns failure with error message' do
          result = service.call

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Este pago ya ha sido completado.')
        end
      end
    end

    context 'when submission fails' do
      before do
        allow(payment).to receive(:document).and_return(double('document').as_null_object)
        allow(payment).to receive(:may_submit?).and_return(false)
        allow(payment).to receive(:update!)
      end

      it 'returns failure with error message' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include('El pago no se puede enviar en su estado actual.')
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(payment).to receive(:document).and_raise(StandardError.new('Attachment failed'))
      end

      it 'returns failure with generic error message' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Ocurrió un error al subir el comprobante.')
      end
    end
  end
end
