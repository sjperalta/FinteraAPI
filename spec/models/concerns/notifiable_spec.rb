# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifiable do
  let(:dummy_class) do
    Class.new do
      include Notifiable
    end
  end
  let(:subject) { dummy_class.new }
  let(:user) { double('User', id: 1) }
  let(:admin) { double('User', id: 2, role: 'admin') }

  before do
    allow(Notification).to receive(:create!)
    allow(User).to receive_message_chain(:where, :find_each).and_yield(admin)
  end

  describe '#create_notification' do
    it 'creates a notification for the user' do
      expect(Notification).to receive(:create!).with(
        user:,
        title: 'Test Title',
        message: 'Test Message',
        notification_type: 'test_type'
      )

      subject.send(:create_notification,
                   user:,
                   title: 'Test Title',
                   message: 'Test Message',
                   notification_type: 'test_type')
    end

    it 'does not create notification when user is nil' do
      expect(Notification).not_to receive(:create!)

      subject.send(:create_notification,
                   user: nil,
                   title: 'Test Title',
                   message: 'Test Message',
                   notification_type: 'test_type')
    end

    it 'logs error when notification creation fails' do
      allow(Notification).to receive(:create!).and_raise(StandardError.new('DB error'))
      expect(Rails.logger).to receive(:error).with('Failed to create notification: DB error')

      subject.send(:create_notification,
                   user:,
                   title: 'Test Title',
                   message: 'Test Message',
                   notification_type: 'test_type')
    end
  end

  describe '#notify_admins' do
    it 'creates notifications for all admins' do
      expect(Notification).to receive(:create!).with(
        user: admin,
        title: 'Admin Title',
        message: 'Admin Message',
        notification_type: 'admin_type'
      )

      subject.send(:notify_admins,
                   title: 'Admin Title',
                   message: 'Admin Message',
                   notification_type: 'admin_type')
    end
  end

  describe '#notify_user_and_admins' do
    it 'creates notifications for user and all admins' do
      expect(Notification).to receive(:create!).with(
        user:,
        title: 'Both Title',
        message: 'Both Message',
        notification_type: 'both_type'
      )

      expect(Notification).to receive(:create!).with(
        user: admin,
        title: 'Both Title',
        message: 'Both Message',
        notification_type: 'both_type'
      )

      subject.send(:notify_user_and_admins,
                   user:,
                   title: 'Both Title',
                   message: 'Both Message',
                   notification_type: 'both_type')
    end
  end
end
