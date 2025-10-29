require 'rails_helper'

RSpec.describe Api::V1::OrganizationsController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #show' do
    it 'returns the organization' do
      get :show, params: { id: organization.id }
      json = JSON.parse(response.body)
      expect(json['id']).to eq(organization.id)
      expect(json['name']).to eq("Test Hospital")
    end

    it 'returns 200 status' do
      get :show, params: { id: organization.id }
      expect(response).to have_http_status(:ok)
    end

    context 'with non-existent organization' do
      it 'returns 404 status' do
        get :show, params: { id: 99999 }
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        get :show, params: { id: 99999 }
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Organization not found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization: {
          name: "New Hospital"
        }
      }
    end

    it 'creates a new organization' do
      expect {
        post :create, params: valid_params
      }.to change(Organization, :count).by(1)
    end

    it 'returns 201 status' do
      post :create, params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'returns organization data' do
      post :create, params: valid_params
      json = JSON.parse(response.body)
      expect(json['name']).to eq("New Hospital")
      expect(json['id']).to be_present
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          organization: {
            name: ""
          }
        }
      end

      it 'does not create organization' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Organization, :count)
      end

      it 'returns 422 status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post :create, params: invalid_params
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
  end
end