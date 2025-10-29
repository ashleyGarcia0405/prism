# frozen_string_literal: true

Given('an organization {string} exists') do |name|
  @organization = Organization.create!(name: name)
end

Given('a user exists with email {string} and password {string}') do |email, password|
  @organization ||= Organization.create!(name: 'Test Org')
  @user = User.create!(
    name: 'Test User',
    email: email,
    password: password,
    organization: @organization
  )
end

Given('I am authenticated as {string}') do |email|
  @organization ||= Organization.create!(name: 'Test Org')
  @user = User.find_or_create_by!(email: email) do |user|
    user.name = 'Test User'
    user.password = 'password123'
    user.organization = @organization
  end
  
  @token = JsonWebToken.encode(user_id: @user.id)
  @headers = { 'Authorization' => "Bearer #{@token}" }
end

When('I register as {string} with email {string} and password {string}') do |name, email, password|
  post '/api/v1/auth/register',
    { user: {
      name: name,
      email: email,
      password: password,
      password_confirmation: password,
      organization_id: @organization.id
    } }.to_json,
    { 'CONTENT_TYPE' => 'application/json' }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I register as {string} with email {string} and password {string} for organization {string}') do |name, email, password, org_name|
  post '/api/v1/auth/register',
    {
      user: {
        name: name,
        email: email,
        password: password,
        password_confirmation: password
      },
      organization: {
        name: org_name
      }
    }.to_json,
    { 'CONTENT_TYPE' => 'application/json' }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I login with email {string} and password {string}') do |email, password|
  post '/api/v1/auth/login',
    { email: email, password: password }.to_json,
    { 'CONTENT_TYPE' => 'application/json' }

  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET {string}') do |path|
  if @headers && @headers['Authorization']
    get path, {}, { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }
  else
    get path
  end
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET {string} without authentication') do |path|
  get path
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET the organization endpoint') do
  path = "/api/v1/organizations/#{@organization.id}"
  if @headers && @headers['Authorization']
    get path, {}, { 'HTTP_AUTHORIZATION' => @headers['Authorization'] }
  else
    get path
  end
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

When('I GET the organization endpoint without authentication') do
  path = "/api/v1/organizations/#{@organization.id}"
  get path
  @response = last_response
  @response_body = JSON.parse(@response.body) rescue {}
end

Then('the response status is {int}') do |status|
  unless @response.status == status
    puts "Response body: #{@response_body.inspect}"
  end
  expect(@response.status).to eq(status)
end

Then('the response contains a JWT token') do
  expect(@response_body['token']).not_to be_nil
  @token = @response_body['token']
end

Then('the token contains user email {string}') do |email|
  decoded = JsonWebToken.decode(@token)
  user = User.find(decoded[:user_id])
  expect(user.email).to eq(email)
end

Then('the response contains error {string}') do |error_message|
  expect(@response_body['error']).to eq(error_message)
end

Then('the response contains organization name {string}') do |org_name|
  expect(@response_body['organization']).not_to be_nil
  expect(@response_body['organization']['name']).to eq(org_name)
end