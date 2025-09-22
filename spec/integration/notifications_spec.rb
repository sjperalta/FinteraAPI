# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::NotificationsController', type: :request do
  let!(:user) do
    User.create!(
      email: 'user@example.com',
      password: 'password123',
      full_name: 'Test User',
      phone: '50449992211',
      identity: '10101010101010',
      rtn: '101010101010101',
      role: 'user',
      confirmed_at: Time.now
    )
  end

  let!(:notification) do
    Notification.create!(
      user:,
      title: 'New Notification',
      message: 'This is a test notification',
      read_at: nil
    )
  end

  let(:Authorization) { "Bearer #{user.generate_jwt}" }

  path '/api/v1/notifications' do
    get 'List all unread notifications' do
      tags 'Notifications'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      response '200', 'Notifications retrieved successfully' do
        let!(:notifications) { [notification] }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['notifications']).to be_an(Array)
          expect(data['notifications'].size).to be >= 1
        end
      end
    end
  end

  path '/api/v1/notifications/{id}' do
    get 'Retrieve a notification' do
      tags 'Notifications'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Notification ID'

      response '200', 'Notification retrieved successfully' do
        let(:id) { notification.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(notification.id)
          expect(data['title']).to eq(notification.title)
        end
      end

      response '404', 'Notification not found' do
        let(:id) { -1 }
        run_test!
      end
    end

    put 'Mark notification as read' do
      tags 'Notifications'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Notification ID'

      response '200', 'Notification marked as read' do
        let(:id) { notification.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['read_at']).not_to be_nil
        end
      end
    end

    delete 'Delete a notification' do
      tags 'Notifications'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response '204', 'Notification deleted successfully' do
        let(:id) { notification.id }
        run_test!
      end

      response '404', 'Notification not found' do
        let(:id) { -1 }
        run_test!
      end
    end
  end

  path '/api/v1/notifications/mark_all_as_read' do
    post 'Mark all notifications as read' do
      tags 'Notifications'
      security [bearerAuth: []]
      consumes 'application/json'
      produces 'application/json'

      response '204', 'All notifications marked as read' do
        before { [notification] }

        run_test!
      end
    end
  end
end
