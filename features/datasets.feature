Feature: Datasets API
  As an authenticated user
  I want to manage datasets for my organization
  So that I can organize and track privacy budgets

  Background:
    Given an organization "TestOrg" exists
    And a user exists with email "user@testorg.com" and password "password123"
    And I am authenticated as "user@testorg.com"

  Scenario: List datasets for an organization
    Given a dataset "Patients" exists for the organization with privacy budget consumed 1.5
    And a dataset "Transactions" exists for the organization with privacy budget consumed 0.8
    When I GET the datasets endpoint for the organization
    Then the response status is 200
    And the response contains 2 datasets
    And the response contains dataset with name "Patients"
    And the response contains dataset with name "Transactions"

  Scenario: Create a dataset successfully
    When I POST to create a dataset with name "HealthRecords"
    Then the response status is 201
    And the response contains dataset with name "HealthRecords"
    And the dataset "HealthRecords" exists for the organization

  Scenario: Create a dataset with missing name
    When I POST to create a dataset with name ""
    Then the response status is 422
    And the response contains an error message

  Scenario: Get privacy budget for a dataset
    Given a dataset "Patients" exists for the organization with privacy budget consumed 1.5
    When I GET the privacy budget for the "Patients" dataset
    Then the response status is 200
    And the response shows total_epsilon 3.0
    And the response shows consumed_epsilon 1.5
    And the response shows remaining_epsilon 1.5

  Scenario: Get privacy budget for dataset without budget
    Given a dataset "NoBudget" exists for the organization without a privacy budget
    When I GET the privacy budget for the "NoBudget" dataset
    Then the response status is 404
    And the response contains error "Privacy budget not found for this dataset"