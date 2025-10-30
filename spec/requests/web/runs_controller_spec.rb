require "rails_helper"

RSpec.describe "Runs (web)", type: :request do
  let(:org)  { Organization.create!(name: "Test Org") }
  let(:user) { org.users.create!(name: "Web User", email: "web@example.com", password: "password123") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    if ApplicationController.method_defined?(:authenticate_web!)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_web!).and_return(true)
    end
    if ApplicationController.method_defined?(:authenticate_user!)
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    end
  end

  it "GET /runs/:id responds OK (HTML)" do
    ds  = org.datasets.create!(name: "Patient Data")
    q   = ds.queries.create!(
      sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
      user: user
    )
    run = q.runs.create!(user: user, status: "completed", result: { "CA" => 1 })
    get "/runs/#{run.id}"
    expect(response).to have_http_status(:ok)
  end
end
