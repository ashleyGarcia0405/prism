require 'json'

# Dataset setup steps are defined in datasets_steps.rb
# Query setup steps are defined in datasets_web_steps.rb

# convenience wrapper for two queries with different SQL
Given('2 queries exist for dataset {string} with SQL {string} and {string}') do |dataset_name, sql1, sql2|
  step %{1 query exists for dataset "#{dataset_name}" with SQL "#{sql1}"}
  step %{1 query exists for dataset "#{dataset_name}" with SQL "#{sql2}"}
end

When('I GET the dashboard') do
  # Extract user_id from @user
  user_id = if @user.respond_to?(:id)
              @user.id
            elsif @user.is_a?(Hash)
              @user[:id] || @user['id']
            end
  
  # Fallback to any user in the current organization if needed
  user_id ||= User.where(organization: @organization).limit(1).pluck(:id).first if @organization
  
  # Pass test_user_id as query parameter for test authentication
  get "/dashboard?test_user_id=#{user_id}"
  
  @response = last_response
  @response_body = begin
    JSON.parse(@response.body)
  rescue
    {}
  end
end

Then('the dashboard contains dataset {string}') do |name|
  # Use @response (or last_response if needed); authentication step's GET should set those
  html = @response ? @response.body : last_response.body
  expect(html).to include(name), "expected dashboard HTML to include dataset name #{name}. HTML snapshot:\n#{html[0..500]}"
end

Then('the dashboard shows total epsilon consumed {float}') do |epsilon|
  html = @response ? @response.body : last_response.body
  regex = /#{Regexp.escape(sprintf('%.2f', epsilon))}|#{Regexp.escape(epsilon.to_s)}/
  expect(html).to match(regex), "expected dashboard to show total epsilon #{epsilon}. HTML snapshot:\n#{html[0..500]}"
end

Then('the dashboard shows total queries {int}') do |count|
  html = @response ? @response.body : last_response.body
  expect(html).to include(count.to_s), "expected dashboard to include query total #{count}. HTML snapshot:\n#{html[0..500]}"
end
