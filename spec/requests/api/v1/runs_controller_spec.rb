# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V1::RunsController", type: :request do
  let(:org)     { create(:organization) }
  let(:user)    { create(:user, organization: org) }
  let(:dataset) { create(:dataset, organization: org) }
  let(:query)   { create(:query, dataset: dataset, user: user) }
  let(:headers) { { "Accept" => "application/json" }.merge(auth_headers_for(user)) }

  describe "GET /api/v1/runs/:id" do
    it "returns run details" do
      run = create(:run, query: query, user: user, status: "completed",
                  result: [{"state"=>"CA","count"=>123}],
                  epsilon_consumed: "0.5", execution_time_ms: 42)
      get "/api/v1/runs/#{run.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("completed")
      expect(json["epsilon_consumed"]).to eq("0.5")
    end
  end

  describe "GET /api/v1/runs/:id/result" do
    it "returns only the result payload" do
      run = create(:run, query: query, user: user, status: "completed",
                  result: [{"state"=>"CA","count"=>123}],
                  epsilon_consumed: "0.5")
      get "/api/v1/runs/#{run.id}/result", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_present
      expect(json["epsilon_consumed"]).to eq("0.5")
    end
  end

  it "requires auth" do
    run = create(:run, query: query, user: user)
    get "/api/v1/runs/#{run.id}"
    expect(response).to have_http_status(:unauthorized)
  end
end
