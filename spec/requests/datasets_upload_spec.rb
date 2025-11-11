# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Datasets upload", type: :request do
  let(:org)  { Organization.create!(name: "Acme") }
  let(:user) { User.create!(name: "U", email: "u@example.com", password: "secret12", organization: org) }

  def auth_headers(user)
    token = JsonWebToken.encode(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end

  it "ingests a small CSV and creates a PG table" do
    # create dataset
    post "/api/v1/organizations/#{org.id}/datasets",
         params: { dataset: { name: "Employees" } },
         headers: auth_headers(user)
    puts "UPLOAD RESPONSE: #{response.body}" unless response.successful?

    expect(response).to have_http_status(:created)
    ds_id = JSON.parse(response.body).fetch("id")

    # upload CSV
    csv_body = <<~CSV
      name,age,active,salary
      Alice,30,true,100000
      Bob,25,false,80000
      Carol,33,true,120000.5
    CSV
    file = Tempfile.new([ "sample", ".csv" ])
    file.write(csv_body); file.rewind

    post "/api/v1/organizations/#{org.id}/datasets/#{ds_id}/upload",
         params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") },
         headers: auth_headers(user)
    puts "UPLOAD RESPONSE: #{response.status} #{response.body}" unless response.successful?

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["row_count"]).to eq(3)
    table = json["table"]
    expect(table).to be_present

    # verify table content
    quoted = ActiveRecord::Base.connection.quote_table_name(table)
    count  = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quoted}").to_i
    expect(count).to eq(3)

    cols = json["columns"].map { |c| [ c["name"], c["sql_type"] ] }.to_h
    expect(cols).to include("age" => "integer", "active" => "boolean")
    expect(cols["salary"]).to eq("double precision")
  ensure
    file&.close!
  end

  it "rejects too-large files" do
    post "/api/v1/organizations/#{org.id}/datasets",
         params: { dataset: { name: "Big" } },
         headers: auth_headers(user)
    ds_id = JSON.parse(response.body).fetch("id")

    big = Tempfile.new([ "big", ".csv" ])
    big.write("x\n")
    big.write("a" * (11 * 1024 * 1024)) # >10MB
    big.rewind

    post "/api/v1/organizations/#{org.id}/datasets/#{ds_id}/upload",
         params: { file: Rack::Test::UploadedFile.new(big.path, "text/csv") },
         headers: auth_headers(user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to match(/File too large/i)
  ensure
    big&.close!
  end
end
