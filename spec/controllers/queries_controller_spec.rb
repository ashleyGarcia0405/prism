# # frozen_string_literal: true
#
# require 'rails_helper'
#
# RSpec.describe QueriesController, type: :controller do
#   let(:organization) { Organization.create!(name: "Test Hospital") }
#   let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
#   let(:dataset) { organization.datasets.create!(name: "Patient Data") }
#   let(:other_org) { Organization.create!(name: "Other Hospital") }
#   let(:other_dataset) { other_org.datasets.create!(name: "Other Data") }
#
#   before do
#     # Simulate logged in user
#     allow(controller).to receive(:current_user).and_return(user)
#   end
#
#   describe 'GET #index' do
#     let!(:query1) { dataset.queries.create!(sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25", user: user) }
#     let!(:query2) { dataset.queries.create!(sql: "SELECT SUM(age) FROM patients", user: user) }
#     let!(:other_query) { other_dataset.queries.create!(sql: "SELECT COUNT(*) FROM other", user: other_org.users.create!(name: "Other", email: "other@example.com", password: "password123")) }
#
#     it 'assigns queries from current user organization' do
#       get :index
#       expect(assigns(:queries)).to match_array([query1, query2])
#     end
#
#     it 'does not include queries from other organizations' do
#       get :index
#       expect(assigns(:queries)).not_to include(other_query)
#     end
#
#     it 'orders queries by created_at desc' do
#       get :index
#       expect(assigns(:queries).first).to eq(query2)
#     end
#
#     it 'renders index template' do
#       get :index
#       expect(response).to render_template(:index)
#     end
#
#     it 'returns 200 status' do
#       get :index
#       expect(response).to have_http_status(:ok)
#     end
#   end
#
#   describe 'GET #show' do
#     let!(:query) { dataset.queries.create!(sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25", user: user) }
#     let!(:run1) { query.runs.create!(user: user, status: "pending") }
#     let!(:run2) { query.runs.create!(user: user, status: "completed") }
#
#     it 'assigns the requested query' do
#       get :show, params: { id: query.id }
#       expect(assigns(:query)).to eq(query)
#     end
#
#     it 'assigns runs ordered by created_at desc' do
#       get :show, params: { id: query.id }
#       expect(assigns(:runs)).to eq([run2, run1])
#     end
#
#     it 'renders show template' do
#       get :show, params: { id: query.id }
#       expect(response).to render_template(:show)
#     end
#
#     it 'returns 200 status' do
#       get :show, params: { id: query.id }
#       expect(response).to have_http_status(:ok)
#     end
#
#     context 'with query from another organization' do
#       let(:other_user) { other_org.users.create!(name: "Other User", email: "other@example.com", password: "password123") }
#       let(:other_query) { other_dataset.queries.create!(sql: "SELECT COUNT(*) FROM other", user: other_user) }
#
#       it 'raises RecordNotFound' do
#         expect {
#           get :show, params: { id: other_query.id }
#         }.to raise_error(ActiveRecord::RecordNotFound)
#       end
#     end
#   end
#
#   describe 'GET #new' do
#     it 'assigns a new query' do
#       get :new
#       expect(assigns(:query)).to be_a_new(Query)
#     end
#
#     it 'assigns datasets from current user organization' do
#       get :new
#       expect(assigns(:datasets)).to eq([dataset])
#     end
#
#     it 'sets dataset_id when provided' do
#       get :new, params: { dataset_id: dataset.id }
#       expect(assigns(:query).dataset_id).to eq(dataset.id)
#     end
#
#     it 'renders new template' do
#       get :new
#       expect(response).to render_template(:new)
#     end
#
#     it 'returns 200 status' do
#       get :new
#       expect(response).to have_http_status(:ok)
#     end
#   end
#
#   describe 'POST #create' do
#     let(:valid_params) do
#       {
#         query: {
#           sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
#           dataset_id: dataset.id
#         }
#       }
#     end
#
#     it 'creates a new query' do
#       expect {
#         post :create, params: valid_params
#       }.to change(Query, :count).by(1)
#     end
#
#     it 'associates query with current user' do
#       post :create, params: valid_params
#       expect(Query.last.user).to eq(user)
#     end
#
#     it 'associates query with dataset' do
#       post :create, params: valid_params
#       expect(Query.last.dataset).to eq(dataset)
#     end
#
#     it 'redirects to query path on success' do
#       post :create, params: valid_params
#       expect(response).to redirect_to(query_path(Query.last))
#     end
#
#     it 'sets success notice' do
#       post :create, params: valid_params
#       expect(flash[:notice]).to eq("Query created successfully!")
#     end
#
#     context 'with invalid params' do
#       let(:invalid_params) do
#         {
#           query: {
#             sql: "SELECT * FROM patients",  # Invalid SQL
#             dataset_id: dataset.id
#           }
#         }
#       end
#
#       it 'does not create a query' do
#         expect {
#           post :create, params: invalid_params
#         }.not_to change(Query, :count)
#       end
#
#       it 'assigns datasets' do
#         post :create, params: invalid_params
#         expect(assigns(:datasets)).to eq([dataset])
#       end
#
#       it 'renders new template' do
#         post :create, params: invalid_params
#         expect(response).to render_template(:new)
#       end
#
#       it 'returns unprocessable_entity status' do
#         post :create, params: invalid_params
#         expect(response).to have_http_status(:unprocessable_entity)
#       end
#     end
#
#     context 'with dataset from another organization' do
#       let(:params_with_other_dataset) do
#         {
#           query: {
#             sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25",
#             dataset_id: other_dataset.id
#           }
#         }
#       end
#
#       it 'raises RecordNotFound' do
#         expect {
#           post :create, params: params_with_other_dataset
#         }.to raise_error(ActiveRecord::RecordNotFound)
#       end
#     end
#
#     context 'with missing dataset_id' do
#       let(:params_without_dataset) do
#         {
#           query: {
#             sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25"
#           }
#         }
#       end
#
#       it 'raises error' do
#         expect {
#           post :create, params: params_without_dataset
#         }.to raise_error
#       end
#     end
#   end
#
#   describe 'POST #execute' do
#     let!(:query) { dataset.queries.create!(sql: "SELECT COUNT(*) FROM patients HAVING COUNT(*) >= 25", user: user) }
#
#     it 'creates a run' do
#       expect {
#         post :execute, params: { id: query.id }
#       }.to change(Run, :count).by(1)
#     end
#
#     it 'sets run status to pending' do
#       post :execute, params: { id: query.id }
#       expect(Run.last.status).to eq("pending")
#     end
#
#     it 'associates run with current user' do
#       post :execute, params: { id: query.id }
#       expect(Run.last.user).to eq(user)
#     end
#
#     it 'enqueues QueryExecutionJob' do
#       expect {
#         post :execute, params: { id: query.id }
#       }.to have_enqueued_job(QueryExecutionJob)
#     end
#
#     it 'redirects to run path' do
#       post :execute, params: { id: query.id }
#       expect(response).to redirect_to(run_path(Run.last))
#     end
#
#     it 'sets success notice' do
#       post :execute, params: { id: query.id }
#       expect(flash[:notice]).to eq("Query execution started...")
#     end
#
#     context 'with query from another organization' do
#       let(:other_user) { other_org.users.create!(name: "Other User", email: "other@example.com", password: "password123") }
#       let(:other_query) { other_dataset.queries.create!(sql: "SELECT COUNT(*) FROM other", user: other_user) }
#
#       it 'raises RecordNotFound' do
#         expect {
#           post :execute, params: { id: other_query.id }
#         }.to raise_error(ActiveRecord::RecordNotFound)
#       end
#     end
#   end
# end