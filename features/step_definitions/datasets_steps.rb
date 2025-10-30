# frozen_string_literal: true

require 'json'

When('I GET the datasets endpoint for the organization') do
  path = "/api/v1/organizations/#{@organization.id}/datasets"
  if @headers && @headers['Authorization']
    get path, {}, { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }
  else
    get path
  end
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I POST to create a dataset with name {string}') do |name|
  path = "/api/v1/organizations/#{@organization.id}/datasets"
  payload = { dataset: { name: name } }.to_json
  
  if @headers && @headers['Authorization']
    post path, payload, { 
      'CONTENT_TYPE' => 'application/json',
      'HTTP_AUTHORIZATION' => @headers['Authorization']
    }
  else
    post path, payload, { 'CONTENT_TYPE' => 'application/json' }
  end
  
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET the privacy budget for the {string} dataset') do |dataset_name|
  dataset = Dataset.find_by(name: dataset_name, organization: @organization)
  raise "Dataset '#{dataset_name}' not found" unless dataset
  
  path = "/api/v1/datasets/#{dataset.id}/budget"
  
  if @headers && @headers['Authorization']
    get path, {}, { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }
  else
    get path
  end
  
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

Then('the response contains {int} datasets') do |count|
  expect(@response_body['datasets']).to be_an(Array)
  expect(@response_body['datasets'].length).to eq(count)
end

Then('the response contains dataset with name {string}') do |name|
  # Handle both single dataset response and array response
  if @response_body['datasets'].is_a?(Array)
    dataset_names = @response_body['datasets'].map { |d| d['name'] }
    expect(dataset_names).to include(name), 
      "expected dataset '#{name}' to be in response. Found: #{dataset_names.inspect}"
  elsif @response_body['name']
    # Single dataset response (from create endpoint)
    expect(@response_body['name']).to eq(name)
  else
    raise "Unexpected response format: #{@response_body.inspect}"
  end
end

Then('the dataset {string} exists for the organization') do |name|
  dataset = Dataset.find_by(name: name, organization: @organization)
  expect(dataset).to be_present, "expected dataset '#{name}' to exist in database"
end

Then('the response shows total_epsilon {float}') do |epsilon|
  # Handle both string and numeric responses from JSON
  actual = @response_body['total_epsilon']
  expect(actual.to_f).to eq(epsilon)
end

Then('the response shows consumed_epsilon {float}') do |epsilon|
  actual = @response_body['consumed_epsilon']
  expect(actual.to_f).to eq(epsilon)
end

Then('the response shows remaining_epsilon {float}') do |epsilon|
  actual = @response_body['remaining_epsilon']
  expect(actual.to_f).to eq(epsilon)
end

Then('the response contains an error message') do
  expect(@response_body['errors']).to be_present
  expect(@response_body['errors']).to be_an(Array)
  expect(@response_body['errors'].length).to be > 0
end

# Reusable dataset setup steps (also used in dashboard tests)
Given('a dataset {string} exists for the organization with privacy budget consumed {float}') do |name, consumed|
  org = @organization || (raise "No @organization: ensure 'Given an organization \"...\" exists' is in Background")
  dataset = Dataset.find_or_create_by!(name: name, organization: org)
  # create or update associated privacy_budget
  if dataset.privacy_budget
    dataset.privacy_budget.update!(total_epsilon: 3.0, consumed_epsilon: consumed)
  else
    dataset.create_privacy_budget!(total_epsilon: 3.0, consumed_epsilon: consumed)
  end
  dataset.reload
  @dataset ||= dataset
end

Given('a dataset {string} exists for the organization without a privacy budget') do |name|
  org = @organization || (raise "No @organization: ensure 'Given an organization \"...\" exists' is in Background")
  dataset = Dataset.find_or_create_by!(name: name, organization: org)
  # explicitly remove privacy_budget if exists to simulate nil
  dataset.privacy_budget&.destroy
  dataset.reload
  @dataset ||= dataset
end