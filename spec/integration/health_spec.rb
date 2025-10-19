# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Healthcheck API', type: :request do
  describe 'GET /api/v1/health' do
    context 'when application is healthy' do
      it 'returns healthy status with database connected' do
        get '/api/v1/health'

        expect(response).to have_http_status(:ok)
        expect(json_response).to include(
          'status' => 'healthy',
          'database' => 'connected'
        )
        expect(json_response).to have_key('timestamp')
        expect(Time.iso8601(json_response['timestamp'])).to be_within(5.seconds).of(Time.current.utc)
      end
    end

    context 'when database query fails' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished,
                                                                            'Connection failed')
      end

      it 'returns unhealthy status with error message' do
        get '/api/v1/health'

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response).to include(
          'status' => 'unhealthy',
          'database' => 'disconnected'
        )
        expect(json_response['error']).to eq('Connection failed')
        expect(json_response).to have_key('timestamp')
      end
    end

    context 'when accessed without authentication' do
      it 'is publicly accessible' do
        get '/api/v1/health'

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('healthy')
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
