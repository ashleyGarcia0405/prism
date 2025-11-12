require 'rails_helper'

RSpec.describe Run, type: :model do
  describe 'associations' do
    it { should belong_to(:query) }
    it { should belong_to(:user) }
  end

  describe 'status enum' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'has pending status' do
      run = query.runs.create!(user: user, status: 'pending')
      expect(run.pending?).to be true
    end

    it 'has running status' do
      run = query.runs.create!(user: user, status: 'running')
      expect(run.running?).to be true
    end

    it 'has completed status' do
      run = query.runs.create!(user: user, status: 'completed')
      expect(run.completed?).to be true
    end

    it 'has failed status' do
      run = query.runs.create!(user: user, status: 'failed')
      expect(run.failed?).to be true
    end
  end

  describe '#completed?' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'returns true when status is completed' do
      run = query.runs.create!(user: user, status: 'completed')
      expect(run.completed?).to be true
    end

    it 'returns false when status is pending' do
      run = query.runs.create!(user: user, status: 'pending')
      expect(run.completed?).to be false
    end

    it 'returns false when status is running' do
      run = query.runs.create!(user: user, status: 'running')
      expect(run.completed?).to be false
    end

    it 'returns false when status is failed' do
      run = query.runs.create!(user: user, status: 'failed')
      expect(run.completed?).to be false
    end
  end

  describe '#failed?' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'returns true when status is failed' do
      run = query.runs.create!(user: user, status: 'failed')
      expect(run.failed?).to be true
    end

    it 'returns false when status is completed' do
      run = query.runs.create!(user: user, status: 'completed')
      expect(run.failed?).to be false
    end

    it 'returns false when status is running' do
      run = query.runs.create!(user: user, status: 'running')
      expect(run.failed?).to be false
    end

    it 'returns false when status is pending' do
      run = query.runs.create!(user: user, status: 'pending')
      expect(run.failed?).to be false
    end
  end

  describe '#running?' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'returns true when status is running' do
      run = query.runs.create!(user: user, status: 'running')
      expect(run.running?).to be true
    end

    it 'returns false when status is completed' do
      run = query.runs.create!(user: user, status: 'completed')
      expect(run.running?).to be false
    end

    it 'returns false when status is failed' do
      run = query.runs.create!(user: user, status: 'failed')
      expect(run.running?).to be false
    end

    it 'returns false when status is pending' do
      run = query.runs.create!(user: user, status: 'pending')
      expect(run.running?).to be false
    end
  end

  describe '#pending?' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'returns true when status is pending' do
      run = query.runs.create!(user: user, status: 'pending')
      expect(run.pending?).to be true
    end

    it 'returns false when status is running' do
      run = query.runs.create!(user: user, status: 'running')
      expect(run.pending?).to be false
    end

    it 'returns false when status is completed' do
      run = query.runs.create!(user: user, status: 'completed')
      expect(run.pending?).to be false
    end

    it 'returns false when status is failed' do
      run = query.runs.create!(user: user, status: 'failed')
      expect(run.pending?).to be false
    end
  end

  describe 'default status' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'defaults to pending status' do
      run = query.runs.create!(user: user)
      expect(run.status).to eq('pending')
      expect(run.pending?).to be true
    end
  end

  describe 'unhappy paths' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )
    end

    it 'requires query association' do
      run = Run.new(user: user, status: 'pending')
      expect(run.save).to be false
      expect(run.errors[:query]).to be_present
    end

    it 'requires user association' do
      run = Run.new(query: query, status: 'pending')
      expect(run.save).to be false
      expect(run.errors[:user]).to be_present
    end

    it 'has default status value' do
      run = Run.new(query: query, user: user)
      expect(run.save).to be true
      expect(run.status).to eq('pending') # has default
    end

    it 'handles invalid status values gracefully' do
      run = query.runs.create!(user: user, status: 'pending')

      # Trying to set invalid status should raise error
      expect {
        run.update!(status: 'invalid_status')
      }.to raise_error(ArgumentError)
    end

    it 'deletes run when query is deleted' do
      run = query.runs.create!(user: user, status: 'pending')
      run_id = run.id

      query.destroy

      expect(Run.exists?(run_id)).to be false
    end
  end
end
