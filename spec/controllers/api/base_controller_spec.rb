require 'rails_helper'

RSpec.describe Api::BaseController, type: :controller do
  controller do
    def index
      render json: { user_id: current_user.id }
    end
  end

  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }

  describe 'authentication' do
    context 'with valid token' do
      let(:token) { JsonWebToken.encode(user_id: user.id) }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'sets current_user' do
        get :index
        json = JSON.parse(response.body)
        expect(json['user_id']).to eq(user.id)
      end

      it 'returns 200 status' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without token' do
      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message' do
        get :index
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Authentication required')
      end
    end

    context 'with invalid token' do
      before do
        request.headers['Authorization'] = "Bearer invalid_token"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with expired token' do
      let(:expired_token) { JsonWebToken.encode({ user_id: user.id }, exp: 1.hour.ago) }

      before do
        request.headers['Authorization'] = "Bearer #{expired_token}"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-existent user' do
      let(:token) { JsonWebToken.encode(user_id: 99999) }

      before do
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
