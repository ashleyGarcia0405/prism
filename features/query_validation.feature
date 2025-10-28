Feature: Query Validation
  As a data analyst
  I want my SQL queries to be validated for safety
  So that I cannot accidentally leak private information

  Background:
    Given an organization "Research Hospital" exists
    And I am authenticated as "analyst@hospital.org"
    And a dataset "Patient Data" exists with default budget

  Scenario: Valid aggregate query with k-anonymity passes
    When I validate SQL:
      """
      SELECT state, AVG(age), COUNT(*)
      FROM patients
      GROUP BY state
      HAVING COUNT(*) >= 25
      """
    Then validation passes
    And estimated epsilon is 0.6

  Scenario: Query with COUNT aggregate passes
    When I validate SQL:
      """
      SELECT diagnosis, COUNT(*)
      FROM patients
      GROUP BY diagnosis
      HAVING COUNT(*) >= 25
      """
    Then validation passes
    And estimated epsilon is 0.1

  Scenario: Query without HAVING clause fails
    When I validate SQL:
      """
      SELECT state, AVG(age)
      FROM patients
      GROUP BY state
      """
    Then validation fails
    And I see validation error "Must include HAVING COUNT(*) >= 25 for k-anonymity"

  Scenario: SELECT * is rejected
    When I validate SQL "SELECT * FROM patients"
    Then validation fails
    And I see validation error "Cannot SELECT * - must use specific aggregates"

  Scenario: Query without GROUP BY fails
    When I validate SQL:
      """
      SELECT AVG(age), COUNT(*)
      FROM patients
      """
    Then validation fails
    And I see validation error "Aggregates require GROUP BY clause"

  Scenario: Subquery is rejected
    When I validate SQL:
      """
      SELECT state, (SELECT COUNT(*) FROM patients p2 WHERE p2.state = p1.state)
      FROM patients p1
      GROUP BY state
      HAVING COUNT(*) >= 25
      """
    Then validation fails
    And I see validation error "Subqueries are not allowed"

  Scenario: Non-aggregate function is rejected
    When I validate SQL "SELECT name, age FROM patients WHERE age > 50"
    Then validation fails
    And I see validation error "Query must use aggregate functions"

  Scenario: Low k-anonymity threshold is rejected
    When I validate SQL:
      """
      SELECT state, COUNT(*)
      FROM patients
      GROUP BY state
      HAVING COUNT(*) >= 5
      """
    Then validation fails
    And I see validation error "Must include HAVING COUNT(*) >= 25 for k-anonymity"

  Scenario: Create query with invalid SQL fails
    When I create a query with SQL "SELECT * FROM patients"
    Then the response status is 422
    And the response contains validation errors

  Scenario: Validate endpoint for valid SQL
    When I POST to "/api/v1/queries/validate" with SQL:
      """
      SELECT zip_code, SUM(income), COUNT(*)
      FROM households
      GROUP BY zip_code
      HAVING COUNT(*) >= 25
      """
    Then the response status is 200
    And the response shows valid true
    And the response shows estimated epsilon

  Scenario: Validate endpoint for invalid SQL
    When I POST to "/api/v1/queries/validate" with SQL "SELECT * FROM patients"
    Then the response status is 422
    And the response shows valid false
    And the response contains error suggestions