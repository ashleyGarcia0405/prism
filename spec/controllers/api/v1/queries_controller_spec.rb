require 'rails_helper'

RSpec.describe Api::V1::QueriesController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'POST #create' do
    context 'with valid SQL' do
      let(:valid_params) do
        {
          query: {
            sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
            dataset_id: dataset.id
          }
        }
      end

      it 'creates a new query' do
        expect {
          post :create, params: valid_params
        }.to change(Query, :count).by(1)
      end

      it 'returns 201 status' do
        post :create, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns query with estimated epsilon' do
        post :create, params: valid_params
        json = JSON.parse(response.body)
        expect(json['estimated_epsilon'].to_f).to eq(0.6)
      end

      it 'associates query with current user' do
        post :create, params: valid_params
        query = Query.last
        expect(query.user_id).to eq(user.id)
      end
    end

    context 'with invalid SQL' do
      let(:invalid_params) do
        {
          query: {
            sql: "SELECT * FROM patients",
            dataset_id: dataset.id
          }
        }
      end

      it 'does not create a query' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Query, :count)
      end

      it 'returns 422 status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :create, params: invalid_params
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns 401 status' do
        post :create, params: { query: { sql: "SELECT 1", dataset_id: dataset.id } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #validate' do
    context 'with valid SQL' do
      let(:valid_params) do
        {
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
        }
      end

      it 'returns valid: true' do
        post :validate, params: valid_params
        json = JSON.parse(response.body)
        expect(json['valid']).to be true
      end

      it 'returns estimated epsilon' do
        post :validate, params: valid_params
        json = JSON.parse(response.body)
        expect(json['estimated_epsilon'].to_f).to eq(0.1)
      end

      it 'returns 200 status' do
        post :validate, params: valid_params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid SQL' do
      let(:invalid_params) do
        {
          sql: "SELECT * FROM patients"
        }
      end

      it 'returns valid: false' do
        post :validate, params: invalid_params
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end

      it 'returns error messages' do
        post :validate, params: invalid_params
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
  end

  describe 'POST #execute' do
    let!(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'creates a run' do
      expect {
        post :execute, params: { id: query.id }
      }.to change(Run, :count).by(1)
    end

    it 'returns 202 status' do
      post :execute, params: { id: query.id }
      expect(response).to have_http_status(:accepted)
    end

    it 'returns run_id' do
      post :execute, params: { id: query.id }
      json = JSON.parse(response.body)
      expect(json['run_id']).to be_present
    end

    it 'returns poll_url' do
      post :execute, params: { id: query.id }
      json = JSON.parse(response.body)
      expect(json['poll_url']).to include("/runs/")
    end

    it 'enqueues QueryExecutionJob' do
      expect {
        post :execute, params: { id: query.id }
      }.to have_enqueued_job(QueryExecutionJob)
    end
  end

  describe 'GET #show' do
    let!(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'returns the query' do
      get :show, params: { id: query.id }
      json = JSON.parse(response.body)
      expect(json['id']).to eq(query.id)
      expect(json['sql']).to eq(query.sql)
    end

    it 'returns 200 status' do
      get :show, params: { id: query.id }
      expect(response).to have_http_status(:ok)
    end
  end
end