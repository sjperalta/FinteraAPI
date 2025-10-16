# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::CreateUserService do
  let(:user_params) do
    {
      email: 'test@example.com',
      full_name: 'Test User',
      phone: '1234567890',
      identity: '123456789',
      rtn: '123456789',
      role: 'user',
      status: 'active',
      locale: 'es'
    }
  end

  let(:creator) do
    User.new(
      id: 1,
      email: 'creator@example.com',
      full_name: 'Creator User'
    )
  end

  let(:admin) do
    User.new(
      id: 2,
      email: 'admin@example.com',
      full_name: 'Admin User',
      role: 'admin'
    )
  end

  let(:service) { described_class.new(user_params:, creator:) }

  describe '#call' do
    context 'when user creation is successful' do
      let(:user) { User.new(user_params.merge(id: 3)) }

      before do
        allow(User).to receive(:new).and_return(user)
        allow(user).to receive(:save).and_return(true)
        allow(user).to receive(:update)
        allow(user).to receive(:send_confirmation_instructions)
        expect(User).to receive_message_chain(:admins, :find_each).and_yield(admin)
        allow(Notification).to receive(:create!)
        allow(UserMailer).to receive_message_chain(:welcome_email, :deliver_later)
      end

      it 'creates a new user with provided params' do
        expect(User).to receive(:new).with(user_params).and_return(user)
        expect(user).to receive(:save).and_return(true)

        service.call
      end

      it 'sets the creator' do
        expect(user).to receive(:update).with(created_by: creator)

        service.call
      end

      it 'sends confirmation instructions' do
        expect(user).to receive(:send_confirmation_instructions)

        service.call
      end

      it 'creates admin notification' do
        expect(Notification).to receive(:create!).with(
          user: admin,
          title: I18n.t('notifications.types.create_new_user'),
          message: I18n.t('notifications.messages.new_user_created_admin', user_name: user.full_name),
          notification_type: 'create_new_user'
        )

        service.call
      end

      it 'creates welcome notification for the user' do
        expect(Notification).to receive(:create!).with(
          user:,
          title: I18n.t('notifications.types.onboard_user'),
          message: I18n.t('notifications.messages.welcome_user', user_name: user.full_name),
          notification_type: 'onboard_user'
        )

        service.call
      end

      it 'sends welcome email to the user' do
        expect(UserMailer).to receive(:welcome_email).with(user).and_return(double(deliver_later: true))

        service.call
      end

      it 'returns success with the user' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
      end
    end

    context 'when user params are blank' do
      let(:user_params) { {} }

      it 'returns failure with error message' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('messages.errors.user_params_required'))
      end
    end

    context 'when user save fails' do
      let(:user) { User.new(user_params) }

      before do
        allow(User).to receive(:new).and_return(user)
        allow(user).to receive(:save).and_return(false)
        allow(user).to receive(:errors).and_return(double(full_messages: ['Email has already been taken']))
      end

      it 'returns failure with validation errors' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email has already been taken')
      end
    end

    context 'when confirmation instructions fail' do
      let(:user) { User.new(user_params.merge(id: 3)) }

      before do
        allow(User).to receive(:new).and_return(user)
        allow(user).to receive(:save).and_return(true)
        allow(user).to receive(:update)
        allow(user).to receive(:send_confirmation_instructions).and_raise(StandardError.new('Mail error'))
        allow(User).to receive_message_chain(:admins, :find_each)
        allow(Notification).to receive(:create!)
        allow(UserMailer).to receive_message_chain(:welcome_email, :deliver_later)
      end

      it 'logs the error but still succeeds' do
        expect(Rails.logger).to receive(:warn).with('Failed to send confirmation instructions: Mail error')

        result = service.call

        expect(result[:success]).to be true
      end
    end

    context 'when notification creation fails' do
      let(:user) { User.new(user_params.merge(id: 3)) }

      before do
        allow(User).to receive(:new).and_return(user)
        allow(user).to receive(:save).and_return(true)
        allow(user).to receive(:update)
        allow(user).to receive(:send_confirmation_instructions)
        allow(User).to receive_message_chain(:admins, :find_each).and_yield(admin)
        allow(Notification).to receive(:create!).and_raise(StandardError.new('Notification error'))
        allow(UserMailer).to receive_message_chain(:welcome_email, :deliver_later)
      end

      it 'logs the error but still succeeds' do
        expect(Rails.logger).to receive(:error).with('Failed to create notifications: Notification error')

        result = service.call

        expect(result[:success]).to be true
      end
    end

    context 'when an unexpected error occurs' do
      let(:creator) { nil }

      before do
        allow(User).to receive(:new).and_raise(StandardError.new('Database connection error'))
      end

      it 'returns failure with generic error message' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include(I18n.t('messages.errors.unexpected_user_creation_error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('Unexpected error creating user: Database connection error')

        service.call
      end
    end
  end
end
