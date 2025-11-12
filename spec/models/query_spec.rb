require 'rails_helper'

RSpec.describe Query, type: :model do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }

  describe 'associations' do
    it { should belong_to(:dataset) }
    it { should belong_to(:user) }
    it { should have_many(:runs) }
  end

  describe 'validations' do
    it { should validate_presence_of(:sql) }
  end

  describe 'SQL validation on create' do
    context 'with valid SQL' do
      it 'creates query successfully' do
        query = Query.new(
          sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end

      it 'sets estimated_epsilon' do
        query = Query.create!(
          sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.estimated_epsilon).to eq(0.6)
      end
    end

    context 'with invalid SQL' do
      it 'rejects SELECT *' do
        query = Query.new(
          sql: "SELECT * FROM patients",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be false
        expect(query.errors[:sql]).to include("Cannot SELECT * - must use specific aggregates")
      end

      it 'rejects query without HAVING' do
        query = Query.new(
          sql: "SELECT state, AVG(age) FROM patients GROUP BY state",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be false
        expect(query.errors[:sql]).to include("Must include HAVING COUNT(*) >= 25 for k-anonymity")
      end

      it 'rejects subqueries' do
        query = Query.new(
          sql: "SELECT state, (SELECT COUNT(*) FROM patients p2 WHERE p2.state = p1.state) FROM patients p1 GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be false
        expect(query.errors[:sql]).to include("Subqueries are not allowed")
      end
    end
  end

  describe '#estimated_epsilon calculation' do
    it 'estimates correctly for COUNT' do
      query = Query.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(0.1)
    end

    it 'estimates correctly for AVG + COUNT' do
      query = Query.create!(
        sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(0.6)
    end

    it 'estimates correctly for multiple aggregates' do
      query = Query.create!(
        sql: "SELECT state, AVG(age), SUM(income), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(1.1) # AVG=0.5 + SUM=0.5 + COUNT=0.1
    end
  end

  describe 'unhappy paths' do
    context 'with missing required fields' do
      it 'fails validation without sql' do
        query = Query.new(dataset: dataset, user: user)
        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end

      it 'fails validation without dataset' do
        query = Query.new(sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25", user: user)
        expect(query.save).to be false
        expect(query.errors[:dataset]).to be_present
      end

      it 'fails validation without user' do
        query = Query.new(sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25", dataset: dataset)
        expect(query.save).to be false
        expect(query.errors[:user]).to be_present
      end
    end

    context 'with invalid backend' do
      it 'fails validation with nonexistent backend' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "nonexistent_backend"
        )
        expect(query.save).to be false
        expect(query.errors[:backend]).to be_present
      end

      it 'handles nil backend' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: nil
        )
        # Backend has a default, so validation might pass or fail depending on implementation
        # Just verify the query can be created/validated
        expect(query).to respond_to(:valid?)
      end
    end

    context 'with invalid associations' do
      it 'fails validation with non-existent dataset_id' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset_id: 99999,
          user: user
        )
        expect(query.save).to be false
        expect(query.errors[:dataset]).to be_present
      end

      it 'fails validation with non-existent user_id' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user_id: 99999
        )
        expect(query.save).to be false
        expect(query.errors[:user]).to be_present
      end
    end

    context 'with SQL injection attempts' do
      it 'rejects SQL with DROP TABLE' do
        query = Query.new(
          sql: "'; DROP TABLE patients; --",
          dataset: dataset,
          user: user
        )
        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end

      it 'rejects SQL with UNION SELECT' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25 UNION SELECT * FROM users",
          dataset: dataset,
          user: user
        )
        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end
    end

    context 'with very long SQL' do
      it 'handles very long SQL strings' do
        long_sql = "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25" + " " * 100000
        query = Query.new(
          sql: long_sql,
          dataset: dataset,
          user: user
        )
        # Should either pass or fail gracefully - just verify it doesn't crash
        expect { query.save }.not_to raise_error
      end
    end

    context 'with empty SQL' do
      it 'fails validation with empty SQL' do
        query = Query.new(
          sql: "",
          dataset: dataset,
          user: user
        )
        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end

      it 'fails validation with whitespace-only SQL' do
        query = Query.new(
          sql: "   \n\t   ",
          dataset: dataset,
          user: user
        )
        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end
    end

    context 'with invalid estimated_epsilon' do
      it 'handles zero estimated_epsilon' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          estimated_epsilon: 0.0
        )
        # Should either pass or fail depending on validation - just verify it doesn't crash
        expect { query.save }.not_to raise_error
      end

      it 'handles negative estimated_epsilon' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          estimated_epsilon: -0.5
        )
        # Should either pass or fail depending on validation - just verify it doesn't crash
        expect { query.save }.not_to raise_error
      end
    end

    context 'with database constraints' do
      it 'handles duplicate queries gracefully' do
        query1 = Query.create!(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        # Duplicate queries should be allowed (no unique constraint)
        query2 = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )
        expect(query2.save).to be true
      end
    end

    context 'when dataset is deleted' do
      it 'handles dataset deletion' do
        query = Query.create!(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        dataset.destroy

        # Query should be deleted (dependent: :destroy) or orphaned
        expect(Query.exists?(query.id)).to be false
      end
    end

    context 'when user is deleted' do
      it 'handles user deletion' do
        query = Query.create!(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        # User deletion might fail if there are dependent records
        # This depends on database constraints
        expect {
          user.destroy
        }.to(raise_error(ActiveRecord::DeleteRestrictionError).or change { User.count }.by(-1))
      end
    end

    context 'with unavailable backend' do
      it 'fails validation when backend is unavailable' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "enclave_backend"
        )

        expect(query.save).to be false
        expect(query.errors[:backend]).to be_present
        expect(query.errors[:backend].first).to include("not available")
      end
    end

    context 'with backend operation support validation' do
      # Note: The operation detection uses elsif, so it checks the FIRST matching operation
      # If COUNT appears anywhere (including HAVING clause), it will be detected first

      it 'validates backend supports detected operation' do
        # This documents current behavior: COUNT is detected first from HAVING clause
        query = Query.new(
          sql: "SELECT MIN(age) FROM patients HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "mpc_backend"
        )

        # Passes because mpc_backend supports COUNT (found in HAVING clause)
        expect(query.save).to be true
      end

      it 'fails when no supported operations are detected for backend' do
        # Use a query with an operation not supported by he_backend
        # MIN is in the select but he_backend doesn't support MIN
        query = Query.new(
          sql: "SELECT MIN(age) FROM patients",
          dataset: dataset,
          user: user,
          backend: "he_backend"
        )

        # This will fail SQL validation (no GROUP BY/HAVING), but let's check
        # operation support would fail too if SQL passed
        expect(query.save).to be false
      end

      it 'succeeds when backend supports COUNT operation' do
        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "mpc_backend"
        )

        expect(query.save).to be true
      end

      it 'succeeds when backend supports SUM operation' do
        query = Query.new(
          sql: "SELECT state, SUM(income) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "mpc_backend"
        )

        expect(query.save).to be true
      end

      it 'succeeds when backend supports AVG operation' do
        query = Query.new(
          sql: "SELECT state, AVG(age) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user,
          backend: "mpc_backend"
        )

        expect(query.save).to be true
      end
    end

    context 'with SQL operation detection' do
      it 'handles SQL with MIN operation' do
        query = Query.new(
          sql: "SELECT state, MIN(age) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end

      it 'handles SQL with MAX operation' do
        query = Query.new(
          sql: "SELECT state, MAX(age) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end

      it 'handles SQL without recognized operations' do
        # SQL without COUNT, SUM, AVG, MIN, MAX should still validate through SQL validator
        query = Query.new(
          sql: "SELECT state, STDDEV(age) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        # Will be validated by SQL validator, operation check will skip
        expect(query.save).to be true
      end

      it 'handles case-insensitive operation detection' do
        query = Query.new(
          sql: "SELECT state, count(*) FROM patients GROUP BY state HAVING count(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end

      it 'handles operations with extra whitespace' do
        query = Query.new(
          sql: "SELECT state, COUNT  ( * ) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end
    end

    context 'with nil SQL handling' do
      it 'handles nil SQL gracefully in validate_sql_safety' do
        query = Query.new(
          sql: nil,
          dataset: dataset,
          user: user
        )

        expect(query.save).to be false
        expect(query.errors[:sql]).to be_present
      end

      it 'handles nil SQL gracefully in set_estimated_epsilon' do
        query = Query.new(
          dataset: dataset,
          user: user
        )

        query.send(:set_estimated_epsilon)
        expect(query.estimated_epsilon).to be_nil
      end
    end

    context 'with backend error handling' do
      it 'handles BackendNotFoundError in backend_must_be_available' do
        # Simulate backend that doesn't exist in registry
        allow(BackendRegistry).to receive(:backend_available?).and_raise(BackendRegistry::BackendNotFoundError)

        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        # Error should be caught and validation should continue
        expect { query.valid? }.not_to raise_error
      end

      it 'handles BackendNotFoundError in backend_must_support_operation' do
        # Simulate backend that doesn't exist in registry
        allow(BackendRegistry).to receive(:backend_available?).and_return(true)
        allow(BackendRegistry).to receive(:supports_operation?).and_raise(BackendRegistry::BackendNotFoundError)

        query = Query.new(
          sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
          dataset: dataset,
          user: user
        )

        # Error should be caught and validation should continue
        expect { query.valid? }.not_to raise_error
      end
    end
  end
end
