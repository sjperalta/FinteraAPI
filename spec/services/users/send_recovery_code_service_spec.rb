# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::SendRecoveryCodeService do
  let(:email) { 'test@example.com' }
  let(:user) { instance_double(User, id: 1, email:, full_name: 'Test User', update!: true) }
  let(:service) { described_class.new(email:) }

  describe '#call' do
    context 'when recovery code is sent successfully' do
      before do
        allow(User).to receive(:find_by).with(email: email.downcase).and_return(user)
        allow(user).to receive(:update!).and_return(true)
        allow(SendResetCodeJob).to receive(:perform_later)
      end

      it 'finds the user by email (downcased)' do
        expect(User).to receive(:find_by).with(email: email.downcase).and_return(user)

        service.call
      end

      it 'generates a recovery code' do
        allow(service).to receive(:generate_recovery_code).and_return('12345')
        expect(user).to receive(:update!).with(hash_including(
                                                 recovery_code: '12345'
                                               ))

        service.call
      end

      it 'enqueues the recovery code email job' do
        expect(SendResetCodeJob).to receive(:perform_later).with(user.id, an_instance_of(String))

        service.call
      end

      it 'returns success with message' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:message]).to eq(I18n.t('messages.success.recovery_code_sent'))
      end

      context 'in development environment' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        it 'uses the development code' do
          expect(user).to receive(:update!).with(hash_including(
                                                   recovery_code: '99999'
                                                 ))

          service.call
        end
      end

      context 'in production environment' do
        before do
          allow(Rails.env).to receive(:development?).and_return(false)
        end

        it 'generates a random code within the specified range' do
          allow(Kernel).to receive(:rand).with(described_class::CODE_RANGE).and_return(42)
          expect(user).to receive(:update!).with(hash_including(
                                                   recovery_code: '42'
                                                 ))

          service.call
        end
      end
    end

    context 'when email is blank' do
      let(:email) { '' }

      it 'returns failure with email required error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t('messages.errors.email_required'))
      end

      it 'does not attempt to find user' do
        expect(User).not_to receive(:find_by)

        service.call
      end
    end

    context 'when email is nil' do
      let(:email) { nil }

      it 'returns failure with email required error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t('messages.errors.email_required'))
      end
    end

    context 'when user is not found' do
      before do
        allow(User).to receive(:find_by).with(email: email.downcase).and_return(nil)
      end

      it 'returns failure with email not found error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t('messages.errors.email_not_found'))
      end

      it 'does not attempt to update user or send email' do
        expect(user).not_to receive(:update!)
        expect(SendResetCodeJob).not_to receive(:perform_later)

        service.call
      end
    end

    context 'when user update fails' do
      before do
        # Use a real User instance and attach an error so ActiveRecord::RecordInvalid
        # can be constructed without hitting missing method bugs on test doubles.
        real_user = User.new(email:)
        real_user.errors.add(:base, 'Some validation error')
        allow(User).to receive(:find_by).with(email: email.downcase).and_return(real_user)
        allow(real_user).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(real_user))
      end

      it 'returns failure with unexpected error' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t('messages.errors.unexpected_error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to update user with recovery code/)

        service.call
      end
    end

    context 'when email enqueue fails' do
      before do
        allow(User).to receive(:find_by).with(email: email.downcase).and_return(user)
        allow(user).to receive(:update!).and_return(true)
        allow(SendResetCodeJob).to receive(:perform_later).and_raise(StandardError.new('Job enqueue failed'))
      end

      it 'logs the email error but still succeeds' do
        expect(Rails.logger).to receive(:error).with(/Failed to enqueue recovery code email/)

        result = service.call

        expect(result[:success]).to be true
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(User).to receive(:find_by).and_raise(StandardError.new('Database connection error'))
      end

      it 'returns failure with unexpected error message' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t('messages.errors.unexpected_error'))
      end

      it 'logs the unexpected error' do
        expect(Rails.logger).to receive(:error).with('Unexpected error sending recovery code: Database connection error')

        service.call
      end
    end
  end

  describe 'constants' do
    it 'defines the development code' do
      expect(described_class::DEVELOPMENT_CODE).to eq('99999')
    end

    it 'defines the code range' do
      expect(described_class::CODE_RANGE).to eq((10_000..99_999))
    end

    it 'defines the code expiry minutes' do
      expect(described_class::CODE_EXPIRY_MINUTES).to eq(15)
    end
  end

  describe 'private methods' do
    describe '#generate_recovery_code' do
      context 'in development' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        it 'returns the development code' do
          expect(service.send(:generate_recovery_code)).to eq('99999')
        end
      end

      context 'in production' do
        before do
          allow(Rails.env).to receive(:development?).and_return(false)
          allow(Kernel).to receive(:rand).with(described_class::CODE_RANGE).and_return(42)
        end

        it 'returns a random code as string' do
          expect(service.send(:generate_recovery_code)).to eq('42')
        end
      end
    end

    describe '#find_user' do
      it 'finds user by downcased email' do
        expect(User).to receive(:find_by).with(email: email.downcase)

        service.send(:find_user)
      end
    end

    describe '#update_user_with_recovery_code' do
      let(:code) { '12345' }

      it 'updates user with recovery code and timestamp' do
        expect(user).to receive(:update!).with(
          recovery_code: code,
          recovery_code_sent_at: an_instance_of(ActiveSupport::TimeWithZone)
        )

        service.send(:update_user_with_recovery_code, user, code)
      end
    end

    describe '#enqueue_recovery_code_email' do
      let(:code) { '12345' }

      it 'enqueues the SendResetCodeJob' do
        expect(SendResetCodeJob).to receive(:perform_later).with(user.id, code)

        service.send(:enqueue_recovery_code_email, user, code)
      end

      it 'logs error if enqueue fails but does not raise' do
        allow(SendResetCodeJob).to receive(:perform_later).and_raise(StandardError.new('Job failed'))
        expect(Rails.logger).to receive(:error).with(/Failed to enqueue recovery code email/)

        expect { service.send(:enqueue_recovery_code_email, user, code) }.not_to raise_error
      end
    end
  end
end
