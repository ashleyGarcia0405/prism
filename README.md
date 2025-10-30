# Prism

Prism is a privacy-preserving analytics platform that allows organizations to:
- Manage sensitive datasets with automatic privacy budget tracking
- Execute SQL queries with differential privacy guarantees
- Track all privacy budget consumption
- Maintain comprehensive audit logs of all operations
- Provide both API and web UI access

## Collaborators
- Ashley Garcia (UNI: ag4647)
- Kai Zhang (UNI: kz2560)
- Fabian Zuluaga Zuluaga (UNI: fz2351)
- John Dong (UNI: jzd2103)

## Grading
The rest is just for thorough documentation but basically to run it and test coverage:
```
# From a fresh clone
# 1) Install dependencies and set up databases
bin/setup

# 2) Start the app (development)
bin/dev
# or
bin/rails server

# 3) Run tests
bundle exec rspec
bundle exec cucumber

# 4) Generate combined coverage (RSpec + Cucumber)
COVERAGE=true bundle exec rspec
COVERAGE=true bundle exec cucumber
# Then open the HTML report at:
# coverage/index.html
```

## Ruby Version

- Ruby 3.3.8
- Rails 8.0

## System Dependencies

- PostgreSQL
- Bundler
- Node.js

## Database Setup

### Development and Test

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed the database (optional)
bin/rails db:seed

# For test environment
RAILS_ENV=test bin/rails db:migrate
```

### Database Configuration

Development and test databases use:
- Database: `prism_development` / `prism_test`
- Username: `prism_user`
- Password: `password`

## Running the Application

```bash
# Start the Rails server
bin/rails server

# Server available at http://localhost:3000
```

## Web UI

Prism includes a complete web interface built with:
- Rails 8 ERB templates
- Tailwind CSS
- Hotwire/Turbo
- Session-based authentication

### Navigating the deployed UI

1. First go to`http://localhost:3000/register`
2. Create an account (organization and user)
3. Creating datasets (not fully implemented, we will use AWS S3 in the next iteration I think)
4. Run a query on a dataset (follows dataset issue, so not functional right now)

### Features

- **Dashboard**: View dataset statistics, total queries, and privacy budget consumption
- **Dataset Management**: Create datasets with automatic privacy budget allocation (3.0ε is the default)
- **Query Builder**: SQL editor with validation and safety rules
- **Query Execution**: Asynchronous query execution + autorefresh
- **Results Viewer**: Formatted results with privacy metrics


### Authentication Endpoints

```bash
# Register new user and organization
POST /api/v1/auth/register
{
  "user": {
    "name": "Alice Chen",
    "email": "alice@hospital.org",
    "password": "secure123"
  },
  "organization": {
    "name": "Memorial Hospital"
  }
}

# Login
POST /api/v1/auth/login
{
  "email": "alice@hospital.org",
  "password": "secure123"
}
```

### Datasets Endpoitns

```bash
# List datasets
GET /api/v1/organizations/:organization_id/datasets

# Create dataset
POST /api/v1/organizations/:organization_id/datasets
{
  "dataset": {
    "name": "Patient Records 2024",
    "description": "Anonymized patient data"
  }
}

# Get privacy budget
GET /api/v1/organizations/:organization_id/datasets/:id/budget
```

### Queries Endpoints

```bash
# Create query
POST /api/v1/organizations/:organization_id/datasets/:dataset_id/queries
{
  "query": {
    "sql": "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
  }
}

# Validate query
POST /api/v1/queries/validate
{
  "sql": "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25"
}

# Execute query
POST /api/v1/queries/:id/execute

# Get query results
GET /api/v1/runs/:id
```

### Audit Endpoint

```bash
# List audit events
GET /api/v1/audit_events?organization_id=:id&action=query_executed
```

## Query Validation Rules

All queries must follow these differential privacy safety rules:

1. **No SELECT \***: Must explicitly specify columns
2. **Aggregate Functions Required**: Must use COUNT, AVG, SUM, MIN, MAX, or STDDEV
3. **GROUP BY Required**: Aggregate queries must include GROUP BY
4. **K-Anonymity**: Must include `HAVING COUNT(*) >= 25`
5. **No Subqueries**: Subqueries are not allowed
6. **Whitelisted Aggregates Only**: Only approved aggregate functions

Sources:
- https://github.com/IBM/differential-privacy-library
- https://arxiv.org/pdf/1907.02444

### Valid Query Example

```sql
SELECT state, AVG(age), COUNT(*)
FROM patients
GROUP BY state
HAVING COUNT(*) >= 25
```

### Invalid Query Examples

```sql
-- Missing HAVING clause
SELECT state, AVG(age) FROM patients GROUP BY state

-- SELECT * not allowed
SELECT * FROM patients

-- Insufficient k-anonymity
SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 10
```

## Privacy Budget Management

Each dataset receives a privacy budget (default: 3.0ε) that tracks:
- **Total Budget**: Initial allocation
- **Consumed**: Epsilon used by completed queries
- **Reserved**: Epsilon reserved for pending queries
- **Remaining**: Available budget for new queries

Budget is automatically:
- Reserved when a query starts execution
- Consumed when query completes successfully
- Released if query fails

## Testing

```bash
# Run all RSpec tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/query_spec.rb

# Run Cucumber features
bundle exec cucumber

# Check code coverage (SimpleCov)
# Coverage report available in coverage/index.html after running tests
```

[//]: # (## Code Quality)

[//]: # ()
[//]: # (```bash)

[//]: # (# Run RuboCop linter)

[//]: # (bundle exec rubocop)

[//]: # ()
[//]: # (# Auto-fix issues)

[//]: # (bundle exec rubocop -a)

[//]: # ()
[//]: # (# Run Brakeman security scanner)

[//]: # (bundle exec brakeman)

[//]: # (```)

## Architecture

### Models

- **Organization**: Top-level entity for multi-tenancy
- **User**: Belongs to organization, uses bcrypt for passwords
- **Dataset**: Contains data, has one privacy budget
- **PrivacyBudget**: Tracks epsilon consumption
- **Query**: SQL query with validation, belongs to dataset and user
- **Run**: Query execution record with results and privacy metrics
- **AuditEvent**: Comprehensive audit logging for all actions

### Services

- **QueryValidator**: Validates SQL queries against DP safety rules
- **DPSandbox**: Executes differential privacy queries (currently stubbed)
- **PrivacyBudgetService**: Manages budget reservation, commit, and rollback
- **AuditLogger**: Logs all system actions

### Jobs

- **QueryExecutionJob**: Asynchronous query execution with privacy budget management

## Authentication

### Web UI
- Session-based authentication
- Stored in Rails session store
- Separate from API authentication

### API
- JWT-based authentication
- Token expires after 24 hours
- Include token in `Authorization: Bearer <token>` header (my preferred way of debugging was just using curl lol)


## Routes


```
GET  /                      # Dashboard
GET  /login                 # Login page
POST /login                 # Login action
GET  /register              # Registration page
POST /register              # Create account
DELETE /logout              # Logout

GET  /datasets              # List datasets
GET  /datasets/new          # New dataset form
POST /datasets              # Create dataset
GET  /datasets/:id          # Dataset details

GET  /queries               # List queries
GET  /datasets/:dataset_id/queries/new  # New query form
POST /datasets/:dataset_id/queries      # Create query
GET  /queries/:id           # Query details
POST /queries/:id/execute   # Execute query

GET  /runs/:id              # View results
GET  /audit_events          # Audit log
```

## Configuration

### Environment Variables (Production)

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname
# or individual variables:
DB_NAME=prism_production
DB_USERNAME=prism_user
DB_PASSWORD=secure_password
DB_HOST=localhost
DB_PORT=5432

# JWT Secret
JWT_SECRET=your_secure_secret_key

# Rails
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=your_rails_secret_key
```

## Project Structure

```
app/
├── controllers/
│   ├── api/
│   │   ├── base_controller.rb      # JWT authentication
│   │   └── v1/                      # API v1 endpoints
│   ├── application_controller.rb   # Session authentication
│   ├── sessions_controller.rb      # Login/logout
│   ├── dashboard_controller.rb     # Dashboard
│   ├── datasets_controller.rb      # Dataset CRUD (web)
│   ├── queries_controller.rb       # Query CRUD (web)
│   ├── runs_controller.rb          # Results viewer
│   └── audit_events_controller.rb  # Audit log
├── models/                          # ActiveRecord models
├── services/                        # Business logic services
├── jobs/                            # Background jobs
└── views/                           # ERB templates

config/
├── routes.rb                        # Route definitions
└── database.yml                     # Database configuration

spec/                                # RSpec tests
features/                            # Cucumber features
```
