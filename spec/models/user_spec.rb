# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject do
    described_class.new(
      full_name: 'Test User',
      phone: '555-0000',
      identity: 'ID123',
      rtn: 'RTN123',
      email: 'user@example.com',
      role: 'user'
    )
  end

  it 'is valid with valid attributes' do
    # Devise expects password fields; set a password to satisfy any callbacks
    subject.password = 'password123'
    subject.password_confirmation = 'password123'
    expect(subject).to be_valid
  end

  it 'is invalid without required attributes' do
    subject.full_name = nil
    expect(subject).to be_invalid
    subject.full_name = 'Test User'
    subject.email = nil
    expect(subject).to be_invalid
  end

  it 'normalizes identity and rtn by stripping whitespace' do
    subject.identity = '  ID999  '
    subject.rtn = '  RTN999  '
    subject.valid?
    expect(subject.identity).to eq('ID999')
    expect(subject.rtn).to eq('RTN999')
  end

  it 'has role helpers' do
    subject.role = 'admin'
    expect(subject.admin?).to be true
    subject.role = 'seller'
    expect(subject.seller?).to be true
  end

  it 'returns :inactive when not active' do
    subject.status = 'inactive'
    expect(subject.inactive_message).to eq(:inactive)
  end

  it 'allows optional note' do
    subject.note = 'Internal note'
    subject.password = 'password123'
    subject.password_confirmation = 'password123'
    expect(subject).to be_valid
  end

  it 'can generate a JWT with user_id payload' do
    # stub id and secret
    allow(subject).to receive(:id).and_return(123)
    original = ENV['SECRET_KEY_BASE']
    ENV['SECRET_KEY_BASE'] = 'test-secret'
    token = subject.generate_jwt
    payload, = JWT.decode(token, ENV['SECRET_KEY_BASE'], true, algorithm: 'HS256')
    expect(payload['user_id']).to eq(123)
    ENV['SECRET_KEY_BASE'] = original
  end
end
