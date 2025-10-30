# frozen_string_literal: true

require 'json'

# Helper to set session before visiting
def set_session_and_visit(path)
  # For Capybara with Rack-Test, directly set the session on the driver
  # The key is to set it BEFORE visiting
  visit "#{path}?test_user_id=#{@user.id}"
end

# Navigation steps for web interface
When('I visit the datasets index page') do
  set_session_and_visit "/datasets"
end

When('I visit the dataset details page for {string}') do |dataset_name|
  dataset = Dataset.find_by(name: dataset_name, organization: @organization)
  raise "Dataset '#{dataset_name}' not found" unless dataset
  
  set_session_and_visit "/datasets/#{dataset.id}"
end

When('I visit the new dataset page') do
  set_session_and_visit "/datasets/new"
end

# Form interaction steps
When('I fill in the dataset form with name {string} and description {string}') do |name, description|
  fill_in 'dataset_name', with: name
  fill_in 'dataset_description', with: description
end

When('I click the create button') do
  click_button 'Create Dataset'
end

# Assertion steps for page content
Then('the page status is {int}') do |status|
  expect(page.status_code).to eq(status)
end

Then('the page displays dataset {string}') do |dataset_name|
  expect(page).to have_content(dataset_name)
end

Then('the page displays dataset name {string}') do |dataset_name|
  expect(page).to have_selector('h1, h2, h3', text: dataset_name)
end

Then('the page displays privacy budget with total_epsilon {float}') do |epsilon|
  expect(page).to have_content("Total Budget") 
  expect(page).to have_content("#{epsilon}ε")
end

Then('the page displays privacy budget with consumed_epsilon {float}') do |epsilon|
  expect(page).to have_content("Consumed")
  formatted_epsilon = sprintf('%.2f', epsilon)
  expect(page).to have_content("#{formatted_epsilon}ε")
end

Then('the page displays {int} recent query') do |count|
  query_rows = page.all('table tbody tr')
  expect(query_rows.length).to eq(count)
end

Then('the page displays {int} recent queries') do |count|
  query_rows = page.all('table tbody tr')
  expect(query_rows.length).to eq(count)
end

Then('the page displays form title {string}') do |title|
  expect(page).to have_selector('h1, h2', text: /#{Regexp.escape(title)}|Create New Dataset/)
end

Then('the page displays a name input field') do
  expect(page).to have_field('dataset_name')
end

Then('the page displays a description input field') do
  expect(page).to have_field('dataset_description')
end

Then('I am redirected to the dataset show page') do
  expect(page.current_path).to match(%r{/datasets/\d+$})
end

Then('the success message shows {string}') do |message|
  expect(page).to have_content(message)
end


# Query setup step
Given('{int} query exists for dataset {string} with SQL {string}') do |count, dataset_name, sql|
  dataset = Dataset.find_by(name: dataset_name, organization: @organization) ||
            Dataset.create!(name: dataset_name, organization: @organization)
  user = @user || User.first || (raise "no user available")

  count.times do |i|
    q = Query.new(
      sql: sql,
      dataset: dataset,
      user: user,
      estimated_epsilon: 0.1
    )
    q.save!(validate: false)

    q.runs.create!(
      status: 'completed',
      user: user,
      backend_used: 'dp_sandbox',
      result: { ok: true },
      epsilon_consumed: 0.1,
      execution_time_ms: 10
    )
    q.reload
  end
end