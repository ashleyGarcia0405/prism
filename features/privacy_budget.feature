Feature: Privacy Budget Management
  As a data analyst
  I want privacy budgets to be tracked per dataset
  So that differential privacy guarantees are maintained

  Background:
    Given an organization "Research Hospital" exists
    And I am authenticated as "researcher@hospital.org"

  Scenario: Dataset gets default privacy budget on creation
    When I create a dataset "Patient Records"
    Then the dataset should have a privacy budget
    And the total epsilon should be 3.0
    And the consumed epsilon should be 0.0
    And the remaining epsilon should be 3.0

  Scenario: View privacy budget for a dataset
    Given a dataset "Medical Data" exists with default budget
    When I GET the budget for the dataset
    Then the response status is 200
    And the response shows total epsilon of 3.0
    And the response shows consumed epsilon of 0.0
    And the response shows remaining epsilon of 3.0

  Scenario: Privacy budget tracks epsilon consumption
    Given a dataset "Patient Data" exists with default budget
    When I consume 0.5 epsilon from the budget
    Then the consumed epsilon should be 0.5
    And the remaining epsilon should be 2.5

  Scenario: Cannot exceed privacy budget
    Given a dataset "Sensitive Data" exists with total epsilon 1.0
    And the dataset has consumed 0.8 epsilon
    When I attempt to reserve 0.5 epsilon
    Then the reservation should fail
    And I should see error "Query would exceed privacy budget"

  Scenario: Privacy budget reservation and commit
    Given a dataset "Clinical Data" exists with default budget
    When I reserve 0.3 epsilon for a query
    Then the reserved epsilon should be 0.3
    And the remaining epsilon should be 2.7
    When I commit the reserved epsilon
    Then the consumed epsilon should be 0.3
    And the reserved epsilon should be 0.0
    And the remaining epsilon should be 2.7

  Scenario: Privacy budget reservation and rollback
    Given a dataset "Trial Data" exists with default budget
    When I reserve 0.4 epsilon for a query
    Then the reserved epsilon should be 0.4
    When I rollback the reservation
    Then the reserved epsilon should be 0.0
    And the remaining epsilon should be 3.0