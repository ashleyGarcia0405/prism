Feature: API Authentication
  As an API user
  I want to authenticate with JWT tokens
  So that I can securely access protected endpoints

  Background:
    Given an organization "Hospital A" exists

  Scenario: User registers successfully
    When I register as "Alice Smith" with email "alice@hospitala.org" and password "secure123"
    Then the response status is 201
    And the response contains a JWT token
    And the token contains user email "alice@hospitala.org"

  Scenario: User logs in successfully
    Given a user exists with email "alice@hospitala.org" and password "secure123"
    When I login with email "alice@hospitala.org" and password "secure123"
    Then the response status is 200
    And the response contains a JWT token
    And the token contains user email "alice@hospitala.org"

  Scenario: Login fails with wrong password
    Given a user exists with email "alice@hospitala.org" and password "secure123"
    When I login with email "alice@hospitala.org" and password "wrongpassword"
    Then the response status is 401
    And the response contains error "Invalid email or password"

  Scenario: Authenticated request to protected endpoint
    Given I am authenticated as "alice@hospitala.org"
    When I GET the organization endpoint
    Then the response status is 200

  Scenario: Unauthenticated request is rejected
    When I GET the organization endpoint without authentication
    Then the response status is 401
    And the response contains error "Authentication required"

  Scenario: User registers with new organization
    When I register as "Bob Jones" with email "bob@newcorp.com" and password "secure456" for organization "NewCorp Research"
    Then the response status is 201
    And the response contains a JWT token
    And the response contains organization name "NewCorp Research"