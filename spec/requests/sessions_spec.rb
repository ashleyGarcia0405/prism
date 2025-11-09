# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, password: 'password123') }

  describe 'GET /login' do
    context 'when not logged in' do
      it 'renders the login form' do
        get login_path
        expect(response).to have_http_status(:success)
      end
    end

    context 'when already logged in' do
      before do
        post login_path, params: { email: user.email, password: 'password123' }
      end

      it 'redirects to dashboard' do
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe 'POST /login' do
    context 'with valid credentials' do
      it 'logs in the user and redirects to dashboard' do
        post login_path, params: { email: user.email, password: 'password123' }

        expect(response).to redirect_to(dashboard_path)
        expect(session[:user_id]).to eq(user.id)
        follow_redirect!
        expect(response.body).to include("Welcome back, #{user.name}!")
      end
    end

    context 'with invalid password' do
      it 'renders the login form with error' do
        post login_path, params: { email: user.email, password: 'wrong_password' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with non-existent email' do
      it 'renders the login form with error' do
        post login_path, params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'GET /register' do
    context 'when not logged in' do
      it 'renders the registration form' do
        get register_path
        expect(response).to have_http_status(:success)
      end
    end

    context 'when already logged in' do
      before do
        post login_path, params: { email: user.email, password: 'password123' }
      end

      it 'redirects to dashboard' do
        get register_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe 'POST /register' do
    let(:valid_params) do
      {
        organization: { name: 'New Org' },
        user: {
          name: 'New User',
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new organization and user' do
        expect {
          post register_path, params: valid_params
        }.to change(Organization, :count).by(1)
         .and change(User, :count).by(1)

        expect(response).to redirect_to(dashboard_path)
        expect(session[:user_id]).to eq(User.last.id)
        follow_redirect!
        expect(response.body).to include('Welcome to Prism, New User!')
      end
    end

    context 'with invalid user parameters' do
      it 'does not create organization or user' do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:email] = 'invalid_email'

        expect {
          post register_path, params: invalid_params
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(session[:user_id]).to be_nil
      end

      it 'rolls back organization creation if user fails' do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:password_confirmation] = 'wrong'

        expect {
          post register_path, params: invalid_params
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid organization parameters' do
      it 'does not create organization or user' do
        invalid_params = valid_params.deep_dup
        invalid_params[:organization][:name] = ''

        expect {
          post register_path, params: invalid_params
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'DELETE /logout' do
    before do
      post login_path, params: { email: user.email, password: 'password123' }
    end

    it 'logs out the user and redirects to login' do
      delete logout_path

      expect(response).to redirect_to(login_path)
      expect(session[:user_id]).to be_nil
      follow_redirect!
      expect(response.body).to include('You have been logged out')
    end
  end
end
