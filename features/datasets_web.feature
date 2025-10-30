Feature: Datasets Web Interface
  As a logged-in user
  I want to manage datasets through the web interface
  So that I can create, view, and organize my datasets

  Background:
    Given an organization "TestOrg" exists
    And a user exists with email "user@testorg.com" and password "password123"
    And I am authenticated as "user@testorg.com"

  Scenario: View list of datasets
    Given a dataset "Patients" exists for the organization with privacy budget consumed 1.5
    And a dataset "Transactions" exists for the organization with privacy budget consumed 0.8
    When I visit the datasets index page
    Then the page status is 200
    And the page displays dataset "Patients"
    And the page displays dataset "Transactions"

  Scenario: View dataset details
    Given a dataset "Patients" exists for the organization with privacy budget consumed 1.5
    And 1 query exists for dataset "Patients" with SQL "SELECT count(*) FROM patients"
    When I visit the dataset details page for "Patients"
    Then the page status is 200
    And the page displays dataset name "Patients"
    And the page displays privacy budget with total_epsilon 3.0
    And the page displays privacy budget with consumed_epsilon 1.5
    And the page displays 1 recent query

  Scenario: Navigate to create new dataset form
    When I visit the new dataset page
    Then the page status is 200
    And the page displays form title "Create New Dataset"
    And the page displays a name input field
    And the page displays a description input field

  Scenario: Create a dataset successfully through web form
    When I visit the new dataset page
    And I fill in the dataset form with name "HealthRecords" and description "Health and medical records"
    And I click the create button
    Then I am redirected to the dataset show page
    And the page displays dataset name "HealthRecords"
    And the success message shows "Dataset created successfully!"

  Scenario: Create a dataset with invalid data
    When I visit the new dataset page
    And I fill in the dataset form with name "" and description "Missing name"
    And I click the create button
    Then the page status is 422