require 'rails_helper'

RSpec.describe Api::V1::DatasetsController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization_id: organization.id,
        dataset: {
          name: "Patient Records 2024",
          description: "Anonymized patient data"
        }
      }
    end

    it 'creates a new dataset' do
      expect {
        post :create, params: valid_params
      }.to change(Dataset, :count).by(1)
    end

    it 'creates privacy budget automatically' do
      post :create, params: valid_params
      dataset = Dataset.last
      expect(dataset.privacy_budget).to be_present
      expect(dataset.privacy_budget.total_epsilon).to eq(3.0)
    end

    it 'returns 201 status' do
      post :create, params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'returns dataset data' do
      post :create, params: valid_params
      json = JSON.parse(response.body)
      expect(json['name']).to eq("Patient Records 2024")
      expect(json['organization_id']).to eq(organization.id)
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          organization_id: organization.id,
          dataset: {
            name: ""
          }
        }
      end

      it 'does not create dataset' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Dataset, :count)
      end

      it 'returns 422 status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #index' do
    let!(:dataset1) { organization.datasets.create!(name: "Dataset 1") }
    let!(:dataset2) { organization.datasets.create!(name: "Dataset 2") }

    it 'returns all datasets for organization' do
      get :index, params: { organization_id: organization.id }
      json = JSON.parse(response.body)
      expect(json['datasets'].size).to eq(2)
    end

    it 'returns 200 status' do
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #budget' do
    let!(:dataset) { organization.datasets.create!(name: "Test Dataset") }

    before do
      dataset.privacy_budget.update!(consumed_epsilon: 1.5)
    end

    it 'returns budget information' do
      get :budget, params: { id: dataset.id }
      json = JSON.parse(response.body)
      expect(json['total_epsilon']).to eq('3.0')
      expect(json['consumed_epsilon']).to eq('1.5')
      expect(json['remaining_epsilon']).to eq('1.5')
    end

    it 'returns 200 status' do
      get :budget, params: { id: dataset.id }
      expect(response).to have_http_status(:ok)
    end
  end
end