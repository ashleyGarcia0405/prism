# frozen_string_literal: true

When('I create a query with SQL {string}') do |sql|
  post '/api/v1/queries',
    { query: { sql: sql, dataset_id: @dataset.id } }.to_json,
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
  @query = Query.find(@response_body['id']) if @response.status == 201
end

Given('a query {string} exists for the dataset') do |sql|
  @query = Query.create!(
    sql: sql,
    dataset: @dataset,
    user: @user,
    estimated_epsilon: 0.5
  )
end

Given('a query with estimated epsilon {float} exists') do |epsilon|
  @query = Query.create!(
    sql: 'SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25',
    dataset: @dataset,
    user: @user,
    estimated_epsilon: epsilon
  )
  @run = @query.runs.create!(status: 'pending', user: @user)
end

Given('a query needing epsilon {float} exists') do |epsilon|
  @query = Query.create!(
    sql: 'SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25',
    dataset: @dataset,
    user: @user,
    estimated_epsilon: epsilon
  )
  @run = @query.runs.create!(status: 'pending', user: @user)
end

Given('the dataset has remaining epsilon {float}') do |epsilon|
  consumed = @dataset.privacy_budget.total_epsilon - epsilon
  @dataset.privacy_budget.update!(consumed_epsilon: consumed)
  @dataset.reload
end

Given('a completed run exists for a query') do
  @query = Query.create!(
    sql: 'SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25',
    dataset: @dataset,
    user: @user,
    estimated_epsilon: 0.5
  )
  @run = @query.runs.create!(
    status: 'completed',
    user: @user,
    backend_used: 'dp_sandbox',
    result: { 'count' => 1234 },
    epsilon_consumed: 0.5,
    execution_time_ms: 250,
    proof_artifacts: { 'mechanism' => 'laplace', 'noise_scale' => 1.0 }
  )
end

When('I execute the query') do
  post "/api/v1/queries/#{@query.id}/execute",
    {},
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
  @run_id = @response_body['run_id']
end

When('the query execution job runs') do
  # manually executing the job for the run
  QueryExecutionJob.perform_now(@run.id)
  @run.reload
end

When('I GET the run details') do
  get "/api/v1/runs/#{@run.id}",
    {},
    { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET the run result endpoint') do
  get "/api/v1/runs/#{@run.id}/result",
    {},
    { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

Then('the query should be stored with estimated epsilon') do
  expect(@query).not_to be_nil
  expect(@query.estimated_epsilon).to be > 0
end

Then('the query should belong to the dataset') do
  expect(@query.dataset_id).to eq(@dataset.id)
end

Then('a run should be created with status {string}') do |status|
  run = Run.find(@run_id)
  expect(run.status).to eq(status)
end

Then('the response should contain a run_id') do
  expect(@response_body['run_id']).not_to be_nil
end

Then('the run status should be {string}') do |status|
  expect(@run.status).to eq(status)
end

Then('the run should have result data') do
  expect(@run.result).not_to be_nil
  expect(@run.result).not_to be_empty
end

Then('the run should have proof artifacts') do
  expect(@run.proof_artifacts).not_to be_nil
  expect(@run.proof_artifacts).not_to be_empty
end

Then('the privacy budget should have consumed {float} epsilon') do |epsilon|
  @dataset.reload
  expect(@dataset.privacy_budget.consumed_epsilon.to_f).to eq(epsilon)
end

Then('the error message should mention {string}') do |text|
  expect(@run.error_message).to include(text)
end

Then('no epsilon should be consumed') do
  @dataset.reload
  budget_before = @dataset.privacy_budget.consumed_epsilon
  # Should remain unchanged from before the failed query
  expect(@dataset.privacy_budget.consumed_epsilon).to eq(budget_before)
end

Then('the response contains status {string}') do |status|
  expect(@response_body['status']).to eq(status)
end

Then('the response contains result data') do
  expect(@response_body['result']).not_to be_nil
end

Then('the response contains epsilon consumed') do
  body = JSON.parse(last_response.body)
  expect(body['epsilon_consumed']).to be_present
end

Then('the response contains execution time') do
  expect(@response_body['execution_time_ms']).not_to be_nil
end

Then('the response contains the result data') do
  body = JSON.parse(last_response.body)
  # result endpoint returns { data: ..., epsilon_consumed: ... }
  expect(body['data']).to be_present
end