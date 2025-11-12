# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::QueriesController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['Content-Type'] = 'application/json'
  end

  describe 'POST #create - parameter validation' do
    context 'with completely missing params' do
      it 'handles empty params gracefully' do
        # When params[:query] is missing, RSpec controller tests may set it to empty hash
        # Either way, we should get a bad_request status
        post :create, params: {}
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        # Could be either 'query parameter is required' or 'dataset_id parameter is required'
        expect(json['errors']).to be_present
        expect(json['errors'].first).to match(/parameter is required/)
      end
    end

    context 'with missing required nested parameters' do
      it 'returns error for missing dataset_id' do
        post :create, params: {
          query: {
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25"
          }
        }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('dataset_id parameter is required')
      end

      it 'returns error for missing sql' do
        post :create, params: {
          query: {
            dataset_id: dataset.id
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'returns error for empty sql string' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: ""
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'returns error for whitespace-only sql' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "   \n\t   "
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with invalid data types' do
      it 'handles string dataset_id instead of integer' do
        post :create, params: {
          query: {
            dataset_id: "not_a_number",
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25"
          }
        }

        expect(response).to have_http_status(:not_found)
      end

      it 'handles negative dataset_id' do
        post :create, params: {
          query: {
            dataset_id: -1,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25"
          }
        }

        expect(response).to have_http_status(:not_found)
      end

      it 'handles array instead of string for sql' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: ["SELECT", "COUNT(*)", "FROM patients"]
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles hash instead of string for sql' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: { select: "COUNT(*)", from: "patients" }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with SQL injection attempts in params' do
      it 'rejects SQL injection in sql field' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "'; DROP TABLE patients; --"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'rejects UNION attacks' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients UNION SELECT * FROM users"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with excessive data sizes' do
      it 'handles very long SQL strings' do
        very_long_sql = "SELECT COUNT(*) FROM patients " + ("WHERE age > 0 " * 1000) + "HAVING COUNT(*) >= 25"

        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: very_long_sql
          }
        }

        # Should either accept or reject gracefully
        expect(response.status).to be_between(200, 422).inclusive
      end

      it 'handles nested parameter bombs' do
        params = { query: { dataset_id: dataset.id, sql: "SELECT COUNT(*)" } }
        1000.times { |i| params["extra_#{i}"] = "value" }

        post :create, params: params

        # Should handle without crashing
        expect(response.status).to be_between(200, 422).inclusive
      end
    end

    context 'with different content types' do
      it 'handles request without explicit Content-Type' do
        # RSpec controller tests handle this automatically
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25"
          }
        }

        # Should still process successfully
        expect([201, 422]).to include(response.status)
      end
    end

    context 'with invalid backend parameter' do
      it 'rejects non-existent backend' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
            backend: "nonexistent_backend"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'rejects unavailable backend' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
            backend: "enclave_backend"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(match(/not available/))
      end

      it 'handles integer backend value' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
            backend: 12345
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with unexpected parameters' do
      it 'ignores extra parameters' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
            unexpected_param: "malicious_value",
            another_param: { nested: "data" }
          }
        }

        # Should succeed, ignoring unexpected params
        expect([200, 201]).to include(response.status)
      end

      it 'handles deeply nested parameters' do
        post :create, params: {
          query: {
            dataset_id: dataset.id,
            sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
            nested: {
              level1: {
                level2: {
                  level3: "deep_value"
                }
              }
            }
          }
        }

        expect([200, 201, 422]).to include(response.status)
      end
    end
  end

  describe 'POST #execute - parameter validation' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
        user: user,
        estimated_epsilon: 0.5
      )
    end

    context 'with missing execution parameters' do
      it 'requires epsilon parameter' do
        post :execute, params: { id: query.id }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('epsilon parameter is required')
      end

      it 'handles nil epsilon' do
        post :execute, params: { id: query.id, epsilon: nil }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('epsilon parameter is required')
      end

      it 'handles string epsilon' do
        post :execute, params: { id: query.id, epsilon: "not_a_number" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('epsilon must be a valid number')
      end

      it 'handles negative epsilon' do
        post :execute, params: { id: query.id, epsilon: -0.5 }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('epsilon must be a positive number')
      end
    end

    context 'with invalid query IDs' do
      it 'handles non-existent query ID' do
        post :execute, params: { id: 99999, epsilon: 0.5 }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Query not found')
      end

      it 'handles string query ID that does not exist' do
        post :execute, params: { id: "99999", epsilon: 0.5 }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Query not found')
      end

      it 'handles negative query ID' do
        post :execute, params: { id: -1, epsilon: 0.5 }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Query not found')
      end

      it 'handles zero query ID' do
        post :execute, params: { id: 0, epsilon: 0.5 }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Query not found')
      end
    end
  end
end