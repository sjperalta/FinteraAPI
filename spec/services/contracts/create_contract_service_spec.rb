# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contracts::CreateContractService do
  let(:admin_user) do
    User.create!(
      email: 'admin@example.com',
      full_name: 'Admin User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '0000000001',
      identity: '1234567891',
      rtn: '1234567891',
      role: 'admin',
      status: 'active',
      locale: 'es',
      confirmed_at: Time.current
    )
  end

  let(:project) do
    Project.create!(
      name: 'Test Project',
      description: 'A test project',
      address: 'Test Address',
      price_per_square_unit: 100.0,
      interest_rate: 5.0,
      commission_rate: 10.0,
      measurement_unit: 'm2'
    )
  end

  let(:lot) do
    Lot.create!(
      project:,
      name: 'Lot 1',
      length: 10.0,
      width: 20.0,
      status: 'available'
    )
  end

  let(:existing_user) do
    User.create!(
      email: 'existing@example.com',
      full_name: 'Existing User',
      password: 'password123',
      password_confirmation: 'password123',
      phone: '0000000002',
      identity: '1234567892',
      rtn: '1234567892',
      role: 'user',
      status: 'active',
      locale: 'es',
      confirmed_at: Time.current
    )
  end

  let(:contract_params) do
    {
      payment_term: 12,
      financing_type: 'direct',
      reserve_amount: 1000.0,
      down_payment: 5000.0
    }
  end

  let(:new_user_params) do
    {
      full_name: 'New User',
      phone: '0000000003',
      identity: '1234567893',
      rtn: '1234567893',
      email: 'new@example.com'
    }
  end

  let(:existing_user_params) do
    {
      full_name: 'Updated User',
      phone: '0000000004',
      identity: '1234567894',
      rtn: '1234567894',
      email: existing_user.email
    }
  end

  let(:valid_document) do
    # Create a mock document for testing
    double('document',
           original_filename: 'test.pdf',
           content_type: 'application/pdf',
           size: 1.megabyte,
           byte_size: 1.megabyte)
  end

  let(:invalid_document) do
    double('document',
           original_filename: 'test.exe',
           content_type: 'application/octet-stream',
           size: 15.megabytes,
           byte_size: 15.megabytes)
  end

  let(:service) do
    described_class.new(
      lot:,
      contract_params:,
      user_params:,
      documents:,
      current_user: admin_user
    )
  end

  let(:user_params) { new_user_params }
  let(:documents) { [] }

  describe '#call' do
    context 'with valid data for new user' do
      it 'creates a contract successfully' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:contract]).to be_a(Contract)
        expect(result[:contract]).to be_persisted
      end

      it 'creates a new user with temporary password' do
        # ensure admin_user exists before measuring User.count changes
        admin_user

        expect { service.call }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq('new@example.com')
        expect(user.full_name).to eq('New User')
        expect(user.role).to eq('user')
        expect(user.creator).to eq(admin_user)
      end

      it 'creates contract with correct associations' do
        result = service.call
        contract = result[:contract]

        expect(contract.lot).to eq(lot)
        expect(contract.creator).to eq(admin_user)
        expect(contract.active).to be true
        # The service submits the contract as part of the flow, so expect 'submitted'
        expect(contract.status).to eq('submitted')
      end

      it 'updates lot status to reserved' do
        service.call

        lot.reload
        expect(lot.status).to eq('reserved')
      end

      it 'submits the contract' do
        result = service.call
        contract = result[:contract]

        expect(contract.status).to eq('submitted')
      end

      it 'creates notifications for user and admins' do
        # ensure admin_user exists and compute expected notifications dynamically
        admin_user
        expected_admins = User.admins.count

        # Two groups: create_new_user + lot_reserved => (1 + admins) * 2
        expect { service.call }.to change(Notification, :count).by((1 + expected_admins) * 2)

        user_notification = Notification.where(user: User.last, notification_type: 'create_new_user').first
        expect(user_notification).to be_present
        expect(user_notification.title).to eq(I18n.t('notifications.types.create_new_user'))

        admin_notifications = Notification.where(notification_type: 'create_new_user').where.not(user: User.last)
        expect(admin_notifications.count).to eq(expected_admins)
      end

      it 'enqueues notification jobs' do
        admin_user

        expect(SendReservationApprovalNotificationJob).to receive(:perform_later)
        expect(NotifyContractSubmissionJob).to receive(:perform_now)

        service.call
      end
    end

    context 'with valid data for existing user' do
      let(:user_params) { existing_user_params }
      let(:contract_params) { super().merge(applicant_user_id: existing_user.id) }

      it 'updates existing user' do
        # ensure admin and existing users are created before measuring
        admin_user
        existing_user

        expect { service.call }.not_to change(User, :count)

        existing_user.reload
        expect(existing_user.full_name).to eq('Updated User')
        expect(existing_user.phone).to eq('0000000004')
      end

      it 'creates contract for existing user' do
        admin_user
        existing_user

        result = service.call

        expect(result[:success]).to be true
        expect(result[:contract].applicant_user).to eq(existing_user)
      end
    end

    context 'with lot not available' do
      before do
        lot.update!(status: 'reserved')
      end

      it 'fails with lot not available error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/lot_not_available/)
      end

      it 'does not create contract or user' do
        expect { service.call }.not_to change(Contract, :count)
        expect { service.call }.not_to change(User, :count)
      end
    end

    context 'with invalid contract data' do
      let(:contract_params) { { payment_term: -1 } }

      it 'fails with validation error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/Validation error/)
      end

      it 'rolls back transaction' do
        expect { service.call }.not_to change(Contract, :count)
        expect { service.call }.not_to change(User, :count)
      end
    end

    context 'with invalid user data' do
      let(:user_params) { { email: 'invalid-email' } }

      it 'fails with validation error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/Validation error/)
      end
    end

    context 'with documents' do
      let(:documents) { [valid_document] }

      before do
        allow(valid_document).to receive(:attach)
      end

      it 'attaches valid documents' do
        # Intercept attach on ActiveStorage collection
        expect_any_instance_of(ActiveStorage::Attached::Many).to receive(:attach).with(valid_document)
        result = service.call
        expect(result[:success]).to be true
      end
    end

    context 'with invalid documents' do
      let(:documents) { [invalid_document] }

      it 'fails with document validation error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/Invalid document format or size/)
      end
    end

    context 'when mailer job fails' do
      before do
        allow(NotifyContractSubmissionJob).to receive(:perform_now).and_raise(StandardError.new('Mailer error'))
      end

      it 'still creates contract successfully' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:contract]).to be_persisted
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to send contract submission notification/)

        service.call
      end

      it 'creates admin notification about mailer failure' do
        # normal notifications + error notification
        expect do
          service.call
        end.to change(Notification, :count).by_at_least(3)
      end
    end

    context 'when reservation notification job fails' do
      before do
        allow(SendReservationApprovalNotificationJob).to receive(:perform_later).and_raise(StandardError.new('Job error'))
      end

      it 'logs the error but continues' do
        expect(Rails.logger).to receive(:error).with(/Failed to enqueue reservation approval notification/)

        result = service.call
        expect(result[:success]).to be true
      end
    end

    context 'when state transition fails' do
      before do
        allow_any_instance_of(Contract).to receive(:valid_for_submission?).and_return(false)
      end

      it 'fails with state transition error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/State transition error/)
      end
    end
  end
end
