require 'swagger_helper'

RSpec.describe 'Api::V1::Statistics', type: :request do
  # create a user without FactoryBot
  let(:user) do
    User.new(
      email: 'test.user@example.com',
      password: 'password123',
      full_name: 'Test User',
      phone: '0000000000',
      identity: '1234567890',
      rtn: '1234567890',
      role: 'admin',
      confirmed_at: Time.current
    ).tap(&:save!)
  end

  before do
    # Stub authentication for request specs
    allow_any_instance_of(Api::V1::StatisticsController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(Api::V1::StatisticsController).to receive(:current_user).and_return(user)
  end

  path '/api/v1/statistics/revenue_flow' do
    get 'Revenue flow datasets' do
      tags 'Statistics'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :year, in: :query, type: :integer, required: false, description: 'Year to fetch'

      response '200', 'Revenue flow retrieved successfully' do
        let(:year) { Date.current.year }
        # Seed revenues so they exist before the request runs (no FactoryBot)
        let!(:rev1) do
          Revenue.new(
            payment_type: 'reservation',
            year:,
            month: 1,
            amount: 1000.0
          ).tap(&:save!)
        end

        let!(:rev2) do
          Revenue.new(
            payment_type: 'installment',
            year:,
            month: Date.current.month,
            amount: 2500.0
          ).tap(&:save!)
        end

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data).to include('year', 'current_month', 'datasets_light', 'datasets_dark', 'labels')
          expect(data['labels'].length).to eq(12)
          expect(data['datasets_light']).to be_an(Array)
          expect(data['datasets_dark']).to be_an(Array)

          # There should be 3 datasets
          expect(data['datasets_light'].length).to eq(3)

          reservation_dataset = data['datasets_light'].detect { |d| d['label'] == 'Reserva' }
          expect(reservation_dataset['data'][0].to_f).to eq(1000.0)

          installment_dataset = data['datasets_light'].detect { |d| d['label'] == 'Cuotas' }
          expect(installment_dataset['data'][Date.current.month - 1].to_f).to eq(2500.0)
        end
      end
    end
  end
end
