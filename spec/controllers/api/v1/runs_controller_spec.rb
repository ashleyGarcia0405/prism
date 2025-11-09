require 'rails_helper'

RSpec.describe Api::V1::RunsController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:query) do
    dataset.queries.create!(
      sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
      user: user
    )
  end
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #show' do
    context 'with completed run' do
      let!(:run) do
        query.runs.create!(
          user: user,
          status: 'completed',
          backend_used: 'dp_sandbox',
          result: { 'count' => 1234 },
          epsilon_consumed: 0.5,
          execution_time_ms: 250,
          proof_artifacts: { 'mechanism' => 'laplace', 'noise_scale' => 1.0 }
        )
      end

      it 'returns the run' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['id']).to eq(run.id)
        expect(json['status']).to eq('completed')
      end

      it 'includes result data' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['result']).to be_present
        expect(json['epsilon_consumed']).to be_present
      end

      it 'includes epsilon_consumed' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['epsilon_consumed']).to eq('0.5')
      end

      it 'includes proof_artifacts' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['proof_artifacts']['mechanism']).to eq('laplace')
      end

      it 'returns 200 status' do
        get :show, params: { id: run.id }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with pending run' do
      let!(:run) do
        query.runs.create!(
          user: user,
          status: 'pending'
        )
      end

      it 'returns pending status' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['status']).to eq('pending')
      end

      it 'does not include result' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['result']).to be_nil
      end
    end

    context 'with failed run' do
      let!(:run) do
        query.runs.create!(
          user: user,
          status: 'failed',
          error_message: 'Insufficient privacy budget'
        )
      end

      it 'returns failed status' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['status']).to eq('failed')
      end

      it 'includes error_message' do
        get :show, params: { id: run.id }
        json = JSON.parse(response.body)
        expect(json['error_message']).to eq('Insufficient privacy budget')
      end
    end
  end

  describe 'GET #result' do
    let!(:run) do
      query.runs.create!(
        user: user,
        status: 'completed',
        result: { 'CA' => 1234, 'NY' => 2345 },
        epsilon_consumed: 0.5
      )
    end

    it 'returns the result' do
      get :result, params: { id: run.id }
      json = JSON.parse(response.body)
      expect(json['data']).to be_present
      expect(json['epsilon_consumed']).to be_present
    end

    it 'includes epsilon_consumed' do
      get :result, params: { id: run.id }
      json = JSON.parse(response.body)
      expect(json['epsilon_consumed']).to eq('0.5')
    end

    it 'returns 200 status' do
      get :result, params: { id: run.id }
      expect(response).to have_http_status(:ok)
    end
  end
end
