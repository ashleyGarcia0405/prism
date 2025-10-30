Feature: Dashboard page
  As a logged-in user
  I want to see my organization's datasets, recent queries, and totals
  So that I can monitor usage and privacy budget consumption

  Background:
    Given an organization "TestOrg" exists
    And I am authenticated as "user@hospital.org"

  Scenario: Dashboard shows datasets, recent queries and totals
    Given a dataset "Patients" exists for the organization with privacy budget consumed 1.5
    And a dataset "NoBudgetDataset" exists for the organization without a privacy budget
    And 2 queries exist for dataset "Patients" with SQL "SELECT count(*) FROM patients" and "SELECT avg(age) FROM patients"
    And 1 query exists for dataset "NoBudgetDataset" with SQL "SELECT id FROM nodata"
    When I GET the dashboard
    Then the response status is 200
    And the dashboard contains dataset "Patients"
    And the dashboard contains dataset "NoBudgetDataset"
    And the dashboard shows total epsilon consumed 1.5
    And the dashboard shows total queries 3

  Scenario: Dashboard handles no datasets gracefully
    Given an organization "TestOrg" exists
    And I am authenticated as "user@hospital.org"
    When I GET the dashboard
    Then the response status is 200
    And the dashboard shows total epsilon consumed 0.0
    And the dashboard shows total queries 0
