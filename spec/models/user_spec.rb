# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:valid_attributes) do
    {
      full_name: 'Test User',
      phone: '555-0000',
      identity: 'ID123',
      rtn: 'RTN123',
      email: 'user@example.com',
      role: 'user',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  subject { described_class.new(valid_attributes) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'is invalid without full_name' do
      subject.full_name = nil
      expect(subject).to be_invalid
      expect(subject.errors[:full_name]).to include('no puede estar en blanco')
    end

    it 'is invalid without phone' do
      subject.phone = nil
      expect(subject).to be_invalid
      expect(subject.errors[:phone]).to include('no puede estar en blanco')
    end

    it 'is invalid without identity' do
      subject.identity = nil
      expect(subject).to be_invalid
      expect(subject.errors[:identity]).to include('no puede estar en blanco')
    end

    it 'is invalid without rtn' do
      subject.rtn = nil
      expect(subject).to be_invalid
      expect(subject.errors[:rtn]).to include('no puede estar en blanco')
    end

    it 'is invalid without email' do
      subject.email = nil
      expect(subject).to be_invalid
      expect(subject.errors[:email]).to include('no puede estar en blanco')
    end

    it 'is invalid with duplicate identity' do
      existing_user = User.new(valid_attributes.merge(identity: 'ID123', email: 'other@example.com'))
      existing_user.skip_confirmation!
      existing_user.save!
      expect(subject).to be_invalid
      expect(subject.errors[:identity]).to include('ya está en uso')
    end

    it 'is invalid with duplicate rtn' do
      existing_user = User.new(valid_attributes.merge(rtn: 'RTN123', email: 'other2@example.com'))
      existing_user.skip_confirmation!
      existing_user.save!
      expect(subject).to be_invalid
      expect(subject.errors[:rtn]).to include('ya está en uso')
    end

    it 'is invalid with duplicate email' do
      existing_user = User.new(valid_attributes.merge(email: 'user@example.com'))
      existing_user.skip_confirmation!
      existing_user.save!
      expect(subject).to be_invalid
      expect(subject.errors[:email]).to include('ya está en uso')
    end

    it 'is invalid with invalid email format' do
      subject.email = 'invalid-email'
      expect(subject).to be_invalid
      expect(subject.errors[:email]).to include('no es válido')
    end

    it 'is invalid with invalid role' do
      subject.role = 'invalid_role'
      expect(subject).to be_invalid
      expect(subject.errors[:role]).to include('no está incluido en la lista')
    end

    it 'is invalid with credit_score below 0' do
      subject.credit_score = -1
      expect(subject).to be_invalid
      expect(subject.errors[:credit_score]).to include('debe ser mayor o igual que 0')
    end

    it 'is invalid with credit_score above 850' do
      subject.credit_score = 851
      expect(subject).to be_invalid
      expect(subject.errors[:credit_score]).to include('debe ser menor o igual que 850')
    end

    it 'is valid with credit_score nil' do
      subject.credit_score = nil
      expect(subject).to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(described_class.statuses).to eq('active' => 'active', 'inactive' => 'inactive', 'suspended' => 'suspended')
    end
  end

  describe 'scopes' do
    let!(:admin) do
      user = User.new(valid_attributes.merge(role: 'admin', email: 'admin@example.com', identity: 'ID1', rtn: 'RTN1'))
      user.skip_confirmation!
      user.save!
      user
    end
    let!(:seller) do
      user = User.new(valid_attributes.merge(role: 'seller', email: 'seller@example.com', identity: 'ID2', rtn: 'RTN2'))
      user.skip_confirmation!
      user.save!
      user
    end
    let!(:user) do
      user = User.new(valid_attributes.merge(role: 'user', email: 'user2@example.com', identity: 'ID3', rtn: 'RTN3'))
      user.skip_confirmation!
      user.save!
      user
    end
    let!(:inactive_user) do
      user = User.new(valid_attributes.merge(role: 'user', status: 'inactive', email: 'inactive@example.com',
                                             identity: 'ID4', rtn: 'RTN4'))
      user.skip_confirmation!
      user.save!
      user
    end

    it 'returns admins' do
      expect(described_class.admins).to include(admin)
      expect(described_class.admins).not_to include(seller, user)
    end

    it 'returns sellers' do
      expect(described_class.sellers).to include(seller)
      expect(described_class.sellers).not_to include(admin, user)
    end

    it 'returns regular_users' do
      expect(described_class.regular_users).to include(user)
      expect(described_class.regular_users).not_to include(admin, seller)
    end

    it 'returns active_users' do
      expect(described_class.active_users).to include(admin, seller, user)
      expect(described_class.active_users).not_to include(inactive_user)
    end
  end

  describe 'callbacks' do
    it 'normalizes identity and rtn by stripping whitespace' do
      subject.identity = '  ID999  '
      subject.rtn = '  RTN999  '
      subject.valid?
      expect(subject.identity).to eq('ID999')
      expect(subject.rtn).to eq('RTN999')
    end
  end

  describe 'methods' do
    describe '#admin?' do
      it 'returns true for admin role' do
        subject.role = 'admin'
        expect(subject.admin?).to be true
      end

      it 'returns false for non-admin role' do
        subject.role = 'user'
        expect(subject.admin?).to be false
      end
    end

    describe '#seller?' do
      it 'returns true for seller role' do
        subject.role = 'seller'
        expect(subject.seller?).to be true
      end

      it 'returns false for non-seller role' do
        subject.role = 'user'
        expect(subject.seller?).to be false
      end
    end

    describe '#generate_jwt' do
      it 'generates a JWT with user_id payload' do
        allow(subject).to receive(:id).and_return(123)
        original = ENV.fetch('SECRET_KEY_BASE', nil)
        ENV['SECRET_KEY_BASE'] = 'test-secret'
        token = subject.generate_jwt
        payload, = JWT.decode(token, ENV.fetch('SECRET_KEY_BASE', nil), true, algorithm: 'HS256')
        expect(payload['user_id']).to eq(123)
        expect(payload['exp']).to be_present
        ENV['SECRET_KEY_BASE'] = original
      end
    end

    describe '#active_for_authentication?' do
      it 'returns true for active user' do
        subject.status = 'active'
        allow(subject).to receive(:discarded?).and_return(false)
        allow(subject).to receive(:confirmed?).and_return(true)
        expect(subject.active_for_authentication?).to be true
      end

      it 'returns false for inactive user' do
        subject.status = 'inactive'
        expect(subject.active_for_authentication?).to be false
      end

      it 'returns false for discarded user' do
        subject.status = 'active'
        allow(subject).to receive(:discarded?).and_return(true)
        expect(subject.active_for_authentication?).to be false
      end
    end

    describe '#inactive_message' do
      it 'returns :inactive when not active' do
        subject.status = 'inactive'
        expect(subject.inactive_message).to eq(:inactive)
      end

      it 'returns super when active' do
        subject.status = 'active'
        expect(subject.inactive_message).to eq(:unconfirmed)
      end
    end

    describe '#can_resend_confirmation_email?' do
      it 'returns true when not confirmed and has confirmation_token' do
        allow(subject).to receive(:confirmed?).and_return(false)
        allow(subject).to receive(:confirmation_token).and_return('token')
        expect(subject.can_resend_confirmation_email?).to be true
      end

      it 'returns false when confirmed' do
        allow(subject).to receive(:confirmed?).and_return(true)
        expect(subject.can_resend_confirmation_email?).to be false
      end

      it 'returns false when no confirmation_token' do
        allow(subject).to receive(:confirmed?).and_return(false)
        allow(subject).to receive(:confirmation_token).and_return(nil)
        expect(subject.can_resend_confirmation_email?).to be false
      end
    end

    describe '#soft_delete' do
      it 'discards the user' do
        subject.skip_confirmation!
        subject.save!
        expect { subject.soft_delete }.to change { subject.discarded? }.from(false).to(true)
      end
    end

    describe '#restore' do
      it 'undiscards the user' do
        subject.skip_confirmation!
        subject.save!
        subject.discard!
        expect { subject.restore }.to change { subject.discarded? }.from(true).to(false)
      end
    end

    describe '#update_credit_score' do
      let(:calculator) { instance_double(CreditScore::CreditScoreCalculator) }

      before do
        allow(CreditScore::CreditScoreCalculator).to receive(:new).and_return(calculator)
        allow(calculator).to receive(:calculate).and_return(750)
      end

      it 'updates credit_score when user has contracts' do
        allow(subject).to receive(:contracts).and_return([double])
        subject.skip_confirmation!
        subject.save!
        subject.update_credit_score
        expect(subject.reload.credit_score).to eq(750)
      end

      it 'does not update when user has no contracts' do
        allow(subject).to receive(:contracts).and_return([])
        subject.skip_confirmation!
        subject.save!
        subject.update_credit_score
        expect(subject.reload.credit_score).to eq(0)
      end

      it 'logs error on failure' do
        allow(subject).to receive(:contracts).and_return([double])
        allow(calculator).to receive(:calculate).and_raise(StandardError.new('error'))
        subject.skip_confirmation!
        subject.save!
        expect(Rails.logger).to receive(:error).with("Failed to update credit score for user ##{subject.id}: error")
        subject.update_credit_score
      end
    end
  end

  describe 'default scope' do
    it 'excludes discarded users by default' do
      kept_user = User.new(valid_attributes.merge(email: 'kept@example.com', identity: 'ID5', rtn: 'RTN5'))
      kept_user.skip_confirmation!
      kept_user.save!
      discarded_user = User.new(valid_attributes.merge(email: 'discarded@example.com', identity: 'ID6', rtn: 'RTN6'))
      discarded_user.skip_confirmation!
      discarded_user.save!
      discarded_user.discard!

      expect(described_class.all).to include(kept_user)
      expect(described_class.all).not_to include(discarded_user)
    end
  end
end
