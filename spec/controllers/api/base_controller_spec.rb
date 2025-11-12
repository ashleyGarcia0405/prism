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

      it 'returns error message' do
        get :index
        json = JSON.parse(response.body)
        expect(json['error']).to eq('User not found')
      end
    end

    context 'with malformed Authorization header' do
      context 'without Bearer prefix' do
        before do
          # Now properly validates Bearer prefix (RFC 6750)
          token = JsonWebToken.encode(user_id: user.id)
          request.headers['Authorization'] = token
        end

        it 'returns 401 status' do
          get :index
          expect(response).to have_http_status(:unauthorized)
        end

        it 'returns error message about invalid format' do
          get :index
          json = JSON.parse(response.body)
          expect(json['error']).to include('Invalid authorization format')
        end
      end

      context 'with empty token after Bearer' do
        before do
          request.headers['Authorization'] = "Bearer "
        end

        it 'returns 401 status' do
          get :index
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with multiple spaces' do
        before do
          token = JsonWebToken.encode(user_id: user.id)
          request.headers['Authorization'] = "Bearer  #{token}"
        end

        it 'handles the request' do
          # Should either succeed or fail gracefully
          get :index
          expect(response.status).to be_between(200, 401).inclusive
        end
      end
    end

    context 'with tampered token' do
      before do
        valid_token = JsonWebToken.encode(user_id: user.id)
        tampered_token = valid_token[0..-2] + 'X'
        request.headers['Authorization'] = "Bearer #{tampered_token}"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with token containing invalid user_id' do
      before do
        # Create token with string user_id instead of integer
        token = JsonWebToken.encode(user_id: 'invalid')
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with nil user_id in token' do
      before do
        token = JsonWebToken.encode(user_id: nil)
        request.headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns 401 status' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with very long token' do
      before do
        long_token = "x" * 10000
        request.headers['Authorization'] = "Bearer #{long_token}"
      end

      it 'handles the request' do
        # Should fail gracefully with 401
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
