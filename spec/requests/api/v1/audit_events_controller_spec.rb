# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::AuditEventsController", type: :request do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, organization: org) }
  let(:hdrs) { { "Accept" => "application/json" }.merge(auth_headers_for(user)) }

  before do
    AuditEvent.create!(user: user, action: "login", metadata: { ua: "rspec" })
    ds = create(:dataset, organization: org)
    AuditEvent.create!(user: user, action: "dataset_created", target: ds, metadata: { name: ds.name })
  end

  it "lists recent events for the org" do
    get "/api/v1/audit_events", params: { organization_id: org.id }, headers: hdrs
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["organization_id"]).to eq(org.id)
    expect(json["count"]).to be >= 1
    expect(json["events"].first).to include("action")
  end

  it "filters by action if provided" do
    get "/api/v1/audit_events", params: { organization_id: org.id, event_action: "login" }, headers: hdrs
    json = JSON.parse(response.body)
    expect(json["events"].all? { |e| e["action"] == "login" }).to be true
  end

  it "requires auth" do
    get "/api/v1/audit_events", params: { organization_id: org.id }
    expect(response).to have_http_status(:unauthorized)
  end
end
