# frozen_string_literal: true

When('I create a dataset {string}') do |name|
  post '/api/v1/organizations/' + @organization.id.to_s + '/datasets',
    { dataset: { name: name } }.to_json,
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
  @dataset = Dataset.find(@response_body['id']) if @response.status == 201
end

Given('a dataset {string} exists with default budget') do |name|
  @dataset = Dataset.create!(name: name, organization: @organization)
  # Privacy budget is automatically created by Dataset after_create callback
end

Given('a dataset {string} exists with total epsilon {float}') do |name, epsilon|
  @dataset = Dataset.create!(name: name, organization: @organization)
  # Update the auto-created budget with custom epsilon
  @dataset.privacy_budget.update!(total_epsilon: epsilon)
end

Given('the dataset has consumed {float} epsilon') do |epsilon|
  @dataset.privacy_budget.update!(consumed_epsilon: epsilon)
end

When('I GET the budget for the dataset') do
  path = "/api/v1/datasets/#{@dataset.id}/budget"
  get path, {}, { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I consume {float} epsilon from the budget') do |epsilon|
  @dataset.privacy_budget.update!(
    consumed_epsilon: @dataset.privacy_budget.consumed_epsilon + epsilon
  )
end

When('I attempt to reserve {float} epsilon') do |epsilon|
  @reservation_result = PrivacyBudgetService.check_and_reserve(
    dataset: @dataset,
    epsilon_needed: epsilon
  )
end

When('I reserve {float} epsilon for a query') do |epsilon|
  @reservation_result = PrivacyBudgetService.check_and_reserve(
    dataset: @dataset,
    epsilon_needed: epsilon
  )
  @reservation_id = @reservation_result[:reservation_id] if @reservation_result[:success]
end

When('I commit the reserved epsilon') do
  PrivacyBudgetService.commit(
    dataset: @dataset,
    reservation_id: @reservation_id,
    actual_epsilon: @dataset.privacy_budget.reserved_epsilon
  )
  @dataset.reload
end

When('I rollback the reservation') do
  PrivacyBudgetService.rollback(
    dataset: @dataset,
    reservation_id: @reservation_id,
    reserved_epsilon: @dataset.privacy_budget.reserved_epsilon
  )
  @dataset.reload
end

Then('the dataset should have a privacy budget') do
  expect(@dataset.privacy_budget).not_to be_nil
end

Then('the total epsilon should be {float}') do |epsilon|
  expect(@dataset.privacy_budget.total_epsilon.to_f).to eq(epsilon)
end

Then('the consumed epsilon should be {float}') do |epsilon|
  expect(@dataset.privacy_budget.consumed_epsilon.to_f).to eq(epsilon)
end

Then('the remaining epsilon should be {float}') do |epsilon|
  budget = @dataset.privacy_budget
  remaining = budget.total_epsilon - budget.consumed_epsilon - budget.reserved_epsilon
  expect(remaining.to_f).to eq(epsilon)
end

Then('the reserved epsilon should be {float}') do |epsilon|
  expect(@dataset.privacy_budget.reserved_epsilon.to_f).to eq(epsilon)
end

Then('the response shows total epsilon of {float}') do |epsilon|
  expect(@response_body['total_epsilon'].to_f).to eq(epsilon)
end

Then('the response shows consumed epsilon of {float}') do |epsilon|
  expect(@response_body['consumed_epsilon'].to_f).to eq(epsilon)
end

Then('the response shows remaining epsilon of {float}') do |epsilon|
  expect(@response_body['remaining_epsilon'].to_f).to eq(epsilon)
end

Then('the reservation should fail') do
  expect(@reservation_result[:success]).to be_falsey
end

Then('I should see error {string}') do |error_message|
  expect(@reservation_result[:error]).to include(error_message)
end