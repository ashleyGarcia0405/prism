# frozen_string_literal: true

When('I validate SQL:') do |sql|
  @sql = sql
  @validation_result = QueryValidator.validate(sql)
end

When('I validate SQL {string}') do |sql|
  @sql = sql
  @validation_result = QueryValidator.validate(sql)
end

When('I POST to {string} with SQL:') do |path, sql|
  post path,
    { sql: sql }.to_json,
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I POST to {string} with SQL {string}') do |path, sql|
  post path,
    { sql: sql }.to_json,
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => @headers['Authorization'] }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

Then('validation passes') do
  expect(@validation_result[:valid]).to be true
end

Then('validation fails') do
  expect(@validation_result[:valid]).to be false
end

Then('estimated epsilon is {float}') do |epsilon|
  expect(@validation_result[:estimated_epsilon].to_f).to be_within(0.01).of(epsilon)
end

Then('I see validation error {string}') do |error_message|
  expect(@validation_result[:errors]).to include(error_message)
end

Then('the response contains validation errors') do
  expect(@response_body['errors']).not_to be_nil
  expect(@response_body['errors']).not_to be_empty
end

Then('the response shows valid true') do
  expect(@response_body['valid']).to be true
end

Then('the response shows valid false') do
  expect(@response_body['valid']).to be false
end

Then('the response shows estimated epsilon') do
  expect(@response_body['estimated_epsilon']).not_to be_nil
  expect(@response_body['estimated_epsilon']).to be > 0
end

Then('the response contains error suggestions') do
  expect(@response_body['errors']).not_to be_nil
end
