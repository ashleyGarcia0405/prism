require 'rails_helper'

RSpec.describe Query, type: :model do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:min_group_size) { QueryValidator::MIN_GROUP_SIZE }

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
          sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
          dataset: dataset,
          user: user
        )

        expect(query.save).to be true
      end

      it 'sets estimated_epsilon' do
        query = Query.create!(
          sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
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
        expect(query.errors[:sql]).to include("Must include HAVING COUNT(*) >= #{min_group_size} for k-anonymity")
      end

      it 'rejects subqueries' do
        query = Query.new(
          sql: "SELECT state, (SELECT COUNT(*) FROM patients p2 WHERE p2.state = p1.state) FROM patients p1 GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
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
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(0.1)
    end

    it 'estimates correctly for AVG + COUNT' do
      query = Query.create!(
        sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(0.6)
    end

    it 'estimates correctly for multiple aggregates' do
      query = Query.create!(
        sql: "SELECT state, AVG(age), SUM(income), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= #{min_group_size}",
        dataset: dataset,
        user: user
      )

      expect(query.estimated_epsilon).to eq(1.1) # AVG=0.5 + SUM=0.5 + COUNT=0.1
    end
  end
end
