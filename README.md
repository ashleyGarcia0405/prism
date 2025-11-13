# Prism
Prism is a privacy-preserving data analytics platform that enables organizations to run SQL queries on sensitive data without exposing plaintext. The system automatically routes queries to the optimal privacy-preserving backend based on query characteristics.

## Collaborators
- Ashley Garcia (UNI: ag4647)
- Kai Zhang (UNI: kz2560)
- Fabian Zuluaga Zuluaga (UNI: fz2351)
- John Dong (UNI: jzd2103)

Heroku link: https://prism-ef53c57bcfab.herokuapp.com/login

Notes: Datarooms is still under construction. Additionally, I have added csv file you can use under the folder sample_data.

## Quick Start (Local Development)

### Prerequisites
- Ruby 3.x
- PostgreSQL
- Bundler

### Initial Setup

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **Start PostgreSQL**
   ```bash
   brew services start postgresql  # macOS
   # or
   sudo service postgresql start   # Linux
   ```

3. **Setup database**
   ```bash
   # Create the database
   bin/rails db:create

   # Run migrations
   bin/rails db:migrate

   # Load seed data
   bin/rails db:seed
   ```

4. **Start the development server**
   ```bash
   bin/rails server
   # Server will be available at http://localhost:3000
   ```

### Development Commands

#### Database Management
```bash
# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Run migrations
bin/rails db:migrate

# Setup test database
RAILS_ENV=test bin/rails db:migrate

# Rollback last migration
bin/rails db:rollback

# Check migration status
bin/rails db:migrate:status
```

#### Running Tests
```bash
# Run all RSpec tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/user_spec.rb:10

# Run Cucumber features (BDD)
bundle exec cucumber

# Run specific feature
bundle exec cucumber features/some_feature.feature
```

#### Code Quality
```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run Brakeman security scanner
bundle exec brakeman
```

#### Rails Console
```bash
# Open Rails console
bin/rails console

# Open console with sandbox (changes are rolled back on exit)
bin/rails console --sandbox
```

### Environment Configuration

The application uses the following database credentials for local development:
- **Database**: `prism_development` (development), `prism_test` (test)
- **Username**: `prism_user`
- **Password**: `password`

For production deployment, set these environment variables:
- `DATABASE_URL` or individual vars: `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (for S3 file uploads)

### API Endpoints

All API endpoints are under the `/api/v1` namespace:

- **Authentication**: `POST /api/v1/auth/login`
- **Organizations**: `/api/v1/organizations`
- **Datasets**: `/api/v1/organizations/:organization_id/datasets`
- **Queries**: `/api/v1/organizations/:organization_id/datasets/:dataset_id/queries`
- **Runs**: Query execution tracking
- **Data Rooms**: Collaborative query spaces
- **Audit Events**: System audit trail

### Troubleshooting

**Database connection issues?**
```bash
# Check if PostgreSQL is running
pg_isready

# Restart PostgreSQL
brew services restart postgresql  # macOS
```

**Permission errors?**
```bash
# Create PostgreSQL user if needed
createuser -s prism_user -P
# Enter password: password
```

**Need a fresh start?**
```bash
# Complete database reset
bin/rails db:reset
```
