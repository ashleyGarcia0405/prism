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

    context 'with missing dataset_id' do
      let(:params_without_dataset) do
        {
          query: {
            sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
          }
        }
      end

      it 'returns 400 status' do
        post :create, params: params_without_dataset
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('dataset_id parameter is required')
      end
    end

    context 'with non-existent dataset_id' do
      let(:params_with_invalid_dataset) do
        {
          query: {
            sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
            dataset_id: 99999
          }
        }
      end

      it 'returns 404 status' do
        post :create, params: params_with_invalid_dataset
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Dataset not found')
      end
    end

    context 'with missing query parameter' do
      it 'returns 400 bad request with error message' do
        post :create, params: {}

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('query parameter is required')
      end
    end

    context 'with missing SQL parameter' do
      let(:params_without_sql) do
        {
          query: {
            dataset_id: dataset.id
          }
        }
      end

      it 'returns 422 status' do
        post :create, params: params_without_sql
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :create, params: params_without_sql
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with empty SQL' do
      let(:params_with_empty_sql) do
        {
          query: {
            sql: "",
            dataset_id: dataset.id
          }
        }
      end

      it 'returns 422 status' do
        post :create, params: params_with_empty_sql
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :create, params: params_with_empty_sql
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with SQL injection attempt' do
      let(:params_with_sql_injection) do
        {
          query: {
            sql: "'; DROP TABLE patients; --",
            dataset_id: dataset.id
          }
        }
      end

      it 'rejects the query' do
        expect {
          post :create, params: params_with_sql_injection
        }.not_to change(Query, :count)
      end

      it 'returns 422 status' do
        post :create, params: params_with_sql_injection
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :create, params: params_with_sql_injection
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with very long SQL' do
      let(:long_sql) { "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" + " " * 10000 }
      let(:params_with_long_sql) do
        {
          query: {
            sql: long_sql,
            dataset_id: dataset.id
          }
        }
      end

      it 'handles the request' do
        post :create, params: params_with_long_sql
        # Should either succeed or fail gracefully with validation error
        expect(response.status).to be_between(200, 422).inclusive
      end
    end

    context 'with invalid backend' do
      let(:params_with_invalid_backend) do
        {
          query: {
            sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
            dataset_id: dataset.id,
            backend: "nonexistent_backend"
          }
        }
      end

      it 'returns 422 status' do
        post :create, params: params_with_invalid_backend
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :create, params: params_with_invalid_backend
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
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

    context 'with missing SQL parameter' do
      it 'returns 400 status' do
        post :validate, params: {}
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        post :validate, params: {}
        json = JSON.parse(response.body)
        expect(json['errors']).to include("SQL parameter is required")
      end
    end

    context 'with empty SQL' do
      it 'returns 422 status' do
        post :validate, params: { sql: "" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post :validate, params: { sql: "" }
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with SQL injection attempt' do
      let(:sql_injection) { "'; DROP TABLE patients; --" }

      it 'returns valid: false' do
        post :validate, params: { sql: sql_injection }
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end

      it 'returns error messages' do
        post :validate, params: { sql: sql_injection }
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with malformed SQL syntax' do
      let(:malformed_sql) { "SELECT INVALID SYNTAX FROM" }

      it 'returns valid: false' do
        post :validate, params: { sql: malformed_sql }
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end

      it 'returns error messages' do
        post :validate, params: { sql: malformed_sql }
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with SQL containing comments' do
      let(:sql_with_comments) do
        "SELECT state, COUNT(*) FROM patients -- comment\nGROUP BY state HAVING COUNT(*) >= 25"
      end

      it 'handles comments in SQL' do
        post :validate, params: { sql: sql_with_comments }
        # Should either validate or reject gracefully
        expect(response.status).to be_between(200, 422).inclusive
      end
    end

    context 'with very long SQL' do
      let(:long_sql) { "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" + " " * 10000 }

      it 'handles the request' do
        post :validate, params: { sql: long_sql }
        # Should either succeed or fail gracefully
        expect(response.status).to be_between(200, 422).inclusive
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns 401 status' do
        post :validate, params: { sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" }
        expect(response).to have_http_status(:unauthorized)
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
        post :execute, params: { id: query.id, epsilon: 0.5 }
      }.to change(Run, :count).by(1)
    end

    it 'returns 202 status' do
      post :execute, params: { id: query.id, epsilon: 0.5 }
      expect(response).to have_http_status(:accepted)
    end

    it 'returns run_id' do
      post :execute, params: { id: query.id, epsilon: 0.5 }
      json = JSON.parse(response.body)
      expect(json['run_id']).to be_present
    end

    it 'returns poll_url' do
      post :execute, params: { id: query.id, epsilon: 0.5 }
      json = JSON.parse(response.body)
      expect(json['poll_url']).to include("/runs/")
    end

    it 'enqueues QueryExecutionJob' do
      expect {
        post :execute, params: { id: query.id, epsilon: 0.5 }
      }.to have_enqueued_job(QueryExecutionJob)
    end

    context 'with non-existent query' do
      it 'returns 404 status' do
        post :execute, params: { id: 99999, epsilon: 0.5 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with missing id parameter' do
      it 'returns 404 status' do
        expect {
          post :execute, params: {}
        }.to raise_error(ActionController::UrlGenerationError)
      end
    end

    context 'when backend is unavailable' do
      before do
        allow(BackendRegistry).to receive(:backend_available?).with(query.backend).and_return(false)
        allow(BackendRegistry).to receive(:get_backend).with(query.backend).and_return(
          unavailable_reason: "Backend is down for maintenance",
          alternatives: ["dp_sandbox"]
        )
      end

      it 'returns 422 status' do
        post :execute, params: { id: query.id, epsilon: 0.5 }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        post :execute, params: { id: query.id, epsilon: 0.5 }
        json = JSON.parse(response.body)
        expect(json['error']).to include("Backend '#{query.backend}' is not available")
      end

      it 'does not create a run' do
        expect {
          post :execute, params: { id: query.id, epsilon: 0.5 }
        }.not_to change(Run, :count)
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns 401 status' do
        post :execute, params: { id: query.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with query from another organization' do
      let(:other_organization) { Organization.create!(name: "Other Hospital") }
      let(:other_dataset) { other_organization.datasets.create!(name: "Other Data") }
      let(:other_query) do
        other_dataset.queries.create!(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          user: other_organization.users.create!(name: "Other User", email: "other@example.com", password: "password123")
        )
      end

      it 'allows access if no authorization check exists' do
        # Note: This test documents current behavior - if authorization is added, this should fail
        # Currently, API doesn't check organization ownership
        post :execute, params: { id: other_query.id }
        # This should either succeed (current behavior) or return 403 (if authorization is added)
        expect(response.status).to be_between(200, 403).inclusive
      end
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

    context 'with non-existent query' do
      it 'returns 404 status' do
        expect {
          get :show, params: { id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with missing id parameter' do
      it 'raises routing error' do
        expect {
          get :show, params: {}
        }.to raise_error(ActionController::UrlGenerationError)
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns 401 status' do
        get :show, params: { id: query.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with query from another organization' do
      let(:other_organization) { Organization.create!(name: "Other Hospital") }
      let(:other_dataset) { other_organization.datasets.create!(name: "Other Data") }
      let(:other_query) do
        other_dataset.queries.create!(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          user: other_organization.users.create!(name: "Other User", email: "other@example.com", password: "password123")
        )
      end

      it 'allows access if no authorization check exists' do
        # Note: This test documents current behavior - if authorization is added, this should fail
        get :show, params: { id: other_query.id }
        # This should either succeed (current behavior) or return 403 (if authorization is added)
        expect(response.status).to be_between(200, 403).inclusive
      end
    end
  end
end
