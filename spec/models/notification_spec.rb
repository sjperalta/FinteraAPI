# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'validations' do
    it 'requires a message' do
      n = Notification.new(user_id: 1)
      expect(n).not_to be_valid
      expect(n.errors[:message]).to include("can't be blank")
    end

    it 'requires a user_id' do
      n = Notification.new(message: 'Hello')
      expect(n).not_to be_valid
      expect(n.errors[:user_id]).to include("can't be blank")
    end
  end

  describe 'read state' do
    it 'is unread when read_at is nil' do
      n = Notification.new(message: 'Hi', user_id: 1)
      expect(n.read?).to be false
    end

    it 'is read when read_at present' do
      n = Notification.new(message: 'Hi', user_id: 1, read_at: Time.current)
      expect(n.read?).to be true
    end

    it 'mark_as_read! calls update! when unread' do
      n = Notification.new(message: 'Hi', user_id: 1)
      expect(n).to receive(:update!).with(hash_including(:read_at))
      n.mark_as_read!
    end
  end
end
