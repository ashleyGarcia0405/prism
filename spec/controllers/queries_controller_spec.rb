# spec/controllers/queries_controller_spec.rb
require 'rails_helper'

RSpec.describe QueriesController, type: :controller do
  let(:org) { Organization.create!(name: "Org A") }
  let(:other_org) { Organization.create!(name: "Org B") }
  let(:user) { org.users.create!(name: "User", email: "u@example.com", password: "pass123") }
  let(:other_user) { other_org.users.create!(name: "Other", email: "o@example.com", password: "pass123") }
  let(:dataset) { org.datasets.create!(name: "Dataset A") }
  let(:other_dataset) { other_org.datasets.create!(name: "Other DS") }

  before do
    session[:user_id] = user.id
  end

  describe "authentication" do
    it "redirects to login when not logged in" do
      session[:user_id] = nil
      get :index
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET #index" do
    it "lists queries for current user's organization" do
      q1 = dataset.queries.create!(sql: "SELECT COUNT(*) FROM t", user: user, backend: 'dp_sandbox')
      q2 = other_dataset.queries.create!(sql: "SELECT COUNT(*) FROM t", user: other_user, backend: 'dp_sandbox')

      get :index
      expect(response).to be_successful
      expect(controller.instance_variable_get(:@queries)).to include(q1)
      expect(controller.instance_variable_get(:@queries)).not_to include(q2)
    end
  end

  describe "GET #show" do
    it "shows a query and its runs for authorized user" do
      q = dataset.queries.create!(sql: "SELECT COUNT(*) FROM t", user: user, backend: 'dp_sandbox')
      r = q.runs.create!(user: user, status: "completed")

      get :show, params: { id: q.id }
      expect(response).to be_successful
      expect(controller.instance_variable_get(:@query)).to eq(q)
      expect(controller.instance_variable_get(:@runs)).to include(r)
    end

    it "does not find queries from other orgs" do
      q_other = other_dataset.queries.create!(sql: "SELECT COUNT(*) FROM t", user: other_user, backend: 'dp_sandbox')
      expect {
        get :show, params: { id: q_other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET #new" do
    it "initializes new query without dataset_id param" do
      get :new, params: { dataset_id: dataset.id }
      expect(response).to be_successful
      expect(controller.instance_variable_get(:@query)).to be_a_new(Query)
      expect(controller.instance_variable_get(:@datasets)).to be_present
    end

    it "pre-fills dataset_id when passed in params" do
      get :new, params: { dataset_id: dataset.id }
      expect(response).to be_successful
      expect(controller.instance_variable_get(:@query).dataset_id).to eq(dataset.id)
    end
  end

  describe "POST #create" do
    it "creates a query and redirects on success" do
      expect {
        post :create, params: { dataset_id: dataset.id, query: { sql: "SELECT COUNT(*) FROM t", dataset_id: dataset.id } }
      }.to change(Query, :count).by(1)

      created = Query.last
      expect(response).to redirect_to(query_path(created))
      expect(flash[:notice]).to match(/created/i)
    end

    it "renders new with status unprocessable_entity on failure" do
      post :create, params: { dataset_id: dataset.id, query: { sql: "", dataset_id: dataset.id } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(controller.instance_variable_get(:@datasets)).to be_present
    end

    it "raises if dataset belongs to another org" do
      expect {
        post :create, params: { dataset_id: other_dataset.id, query: { sql: "SELECT 1", dataset_id: other_dataset.id } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST #execute" do
    it "creates a run, enqueues job, and redirects to run" do
      q = dataset.queries.create!(sql: "SELECT COUNT(*) FROM t", user: user, backend: 'dp_sandbox')

      expect(QueryExecutionJob).to receive(:perform_later).with(kind_of(Integer))

      post :execute, params: { id: q.id }

      run = Run.order(:created_at).last
      expect(response).to redirect_to(run_path(run))
      expect(flash[:notice]).to match(/started/i)
      expect(run.user).to eq(user)
      expect(run.status).to eq("pending")
    end
  end
end