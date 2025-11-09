# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::QueriesController", type: :request do
  let(:org)     { create(:organization) }
  let(:user)    { create(:user, organization: org) }
  let(:dataset) { create(:dataset, organization: org) }
  let(:headers) { { "Content-Type" => "application/json" }.merge(auth_headers_for(user)) }

  describe "POST /api/v1/queries" do
    it "creates a query and returns 201 with payload, logs audit" do
      body = {
        query: {
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset_id: dataset.id
        }
      }.to_json

      expect {
        post "/api/v1/queries", params: body, headers: headers
      }.to change { Query.count }.by(1)
       .and change { AuditEvent.where(action: "query_created").count }.by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["estimated_epsilon"]).to eq("0.1")
      expect(json["dataset_id"]).to eq(dataset.id)
    end

    it "rejects invalid SQL with 422" do
      body = { query: { sql: "SELECT * FROM patients", dataset_id: dataset.id } }.to_json
      post "/api/v1/queries", params: body, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "requires auth" do
      post "/api/v1/queries", params: {}.to_json, headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/queries/:id" do
    it "returns the query JSON" do
      q = create(:query, dataset: dataset, user: user)
      get "/api/v1/queries/#{q.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(q.id)
      expect(json["sql"]).to eq(q.sql)
      expect(json["estimated_epsilon"].to_s.to_d).to eq(q.estimated_epsilon.to_d)
    end
  end

  describe "POST /api/v1/queries/validate" do
    it "returns 200 for valid aggregate with k-anonymity" do
      body = {
        sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
      }.to_json
      post "/api/v1/queries/validate", params: body, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["valid"]).to eq(true)
      expect(json["estimated_epsilon"]).to be_present
    end

    it "returns 422 for invalid SQL" do
      post "/api/v1/queries/validate", params: { sql: "SELECT * FROM patients" }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["valid"]).to eq(false)
      expect(json["errors"]).to be_present
    end
  end

  describe "POST /api/v1/queries/:id/execute" do
    it "enqueues job, creates pending run and returns 202" do
      q = create(:query, dataset: dataset, user: user)

      ActiveJob::Base.queue_adapter = :test
      expect {
        post "/api/v1/queries/#{q.id}/execute", headers: headers
      }.to change { Run.count }.by(1)

      expect(enqueued_jobs.size).to eq(1)
      expect(response).to have_http_status(:accepted)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("pending")
      expect(json["run_id"]).to be_present
    end
  end
end
