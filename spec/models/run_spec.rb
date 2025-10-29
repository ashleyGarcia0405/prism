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
  end
end
