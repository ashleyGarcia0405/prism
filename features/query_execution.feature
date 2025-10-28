Feature: Query Execution
  As a data analyst
  I want to execute differential privacy queries asynchronously
  So that I can analyze sensitive data safely

  Background:
    Given an organization "Research Hospital" exists
    And I am authenticated as "analyst@hospital.org"
    And a dataset "Patient Data" exists with default budget

  Scenario: Create a query
    When I create a query with SQL "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
    Then the response status is 201
    And the query should be stored with estimated epsilon
    And the query should belong to the dataset

  Scenario: Execute query asynchronously
    Given a query "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" exists for the dataset
    When I execute the query
    Then the response status is 202
    And a run should be created with status "pending"
    And the response should contain a run_id

  Scenario: Query execution completes successfully
    Given a query with estimated epsilon 0.5 exists
    When the query execution job runs
    Then the run status should be "completed"
    And the run should have result data
    And the run should have proof artifacts
    And the privacy budget should have consumed 0.5 epsilon

  Scenario: Query execution consumes privacy budget
    Given the dataset has remaining epsilon 3.0
    And a query with estimated epsilon 0.5 exists
    When the query execution job runs
    Then the consumed epsilon should be 0.5
    And the remaining epsilon should be 2.5

  Scenario: Query fails when budget exceeded
    Given the dataset has remaining epsilon 0.3
    And a query needing epsilon 0.5 exists
    When the query execution job runs
    Then the run status should be "failed"
    And the error message should mention "privacy budget"
    And no epsilon should be consumed

  Scenario: Poll for query results
    Given a completed run exists for a query
    When I GET the run details
    Then the response status is 200
    And the response contains status "completed"
    And the response contains result data
    And the response contains epsilon consumed
    And the response contains execution time

  Scenario: Get query result endpoint
    Given a completed run exists for a query
    When I GET the run result endpoint
    Then the response status is 200
    And the response contains the result data
    And the response contains epsilon consumed