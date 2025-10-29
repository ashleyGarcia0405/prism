require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :controller do
  describe 'POST #register' do
    context 'with valid parameters and new organization' do
      let(:valid_params) do
        {
          user: {
            name: "John Doe",
            email: "john@example.com",
            password: "password123"
          },
          organization: {
            name: "Acme Corp"
          }
        }
      end

      it 'creates a new user' do
        expect {
          post :register, params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'creates a new organization' do
        expect {
          post :register, params: valid_params
        }.to change(Organization, :count).by(1)
      end

      it 'returns a JWT token' do
        post :register, params: valid_params
        json = JSON.parse(response.body)
        expect(json['token']).to be_present
      end

      it 'returns user information' do
        post :register, params: valid_params
        json = JSON.parse(response.body)
        expect(json['user']['email']).to eq('john@example.com')
        expect(json['user']['name']).to eq('John Doe')
      end

      it 'returns 201 status' do
        post :register, params: valid_params
        expect(response).to have_http_status(:created)
      end
    end

    context 'with existing organization_id' do
      let!(:existing_org) { Organization.create!(name: "Existing Org") }
      let(:valid_params) do
        {
          user: {
            name: "Jane Doe",
            email: "jane@example.com",
            password: "password123",
            organization_id: existing_org.id
          }
        }
      end

      it 'uses existing organization' do
        expect {
          post :register, params: valid_params
        }.not_to change(Organization, :count)
      end

      it 'creates user under existing org' do
        post :register, params: valid_params
        user = User.last
        expect(user.organization_id).to eq(existing_org.id)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          user: {
            name: "John",
            email: "invalid-email",
            password: "123"
          }
        }
      end

      it 'returns 422 status' do
        post :register, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post :register, params: invalid_params
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'without organization' do
      let(:params_without_org) do
        {
          user: {
            name: "John Doe",
            email: "john@example.com",
            password: "password123"
          }
        }
      end

      it 'returns error' do
        post :register, params: params_without_org
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST #login' do
    let!(:organization) { Organization.create!(name: "Test Org") }
    let!(:user) do
      organization.users.create!(
        name: "Test User",
        email: "test@example.com",
        password: "password123"
      )
    end

    context 'with valid credentials' do
      let(:valid_credentials) do
        {
          email: "test@example.com",
          password: "password123"
        }
      end

      it 'returns JWT token' do
        post :login, params: valid_credentials
        json = JSON.parse(response.body)
        expect(json['token']).to be_present
      end

      it 'returns 200 status' do
        post :login, params: valid_credentials
        expect(response).to have_http_status(:ok)
      end

      it 'returns user information' do
        post :login, params: valid_credentials
        json = JSON.parse(response.body)
        expect(json['user']['email']).to eq('test@example.com')
      end
    end

    context 'with invalid password' do
      let(:invalid_credentials) do
        {
          email: "test@example.com",
          password: "wrongpassword"
        }
      end

      it 'returns 401 status' do
        post :login, params: invalid_credentials
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message' do
        post :login, params: invalid_credentials
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid email or password')
      end
    end

    context 'with non-existent email' do
      let(:invalid_credentials) do
        {
          email: "nonexistent@example.com",
          password: "password123"
        }
      end

      it 'returns 401 status' do
        post :login, params: invalid_credentials
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end