require 'rails_helper'

RSpec.describe AuditEvent, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should belong_to(:target).optional }
  end

  describe 'action enum' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }

    it 'has login action' do
      event = AuditEvent.create!(user: user, action: 'login')
      expect(event.login_action?).to be true
    end

    it 'has dataset_created action' do
      event = AuditEvent.create!(user: user, action: 'dataset_created')
      expect(event.dataset_created_action?).to be true
    end

    it 'has query_created action' do
      event = AuditEvent.create!(user: user, action: 'query_created')
      expect(event.query_created_action?).to be true
    end

    it 'has query_executed action' do
      event = AuditEvent.create!(user: user, action: 'query_executed')
      expect(event.query_executed_action?).to be true
    end

    it 'has query_failed action' do
      event = AuditEvent.create!(user: user, action: 'query_failed')
      expect(event.query_failed_action?).to be true
    end

    it 'has privacy_budget_exhausted action' do
      event = AuditEvent.create!(user: user, action: 'privacy_budget_exhausted')
      expect(event.privacy_budget_exhausted_action?).to be true
    end
  end

  describe 'polymorphic target' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
    let(:dataset) { organization.datasets.create!(name: "Test Dataset") }

    it 'can have a dataset as target' do
      event = AuditEvent.create!(
        user: user,
        action: 'dataset_created',
        target: dataset
      )

      expect(event.target).to eq(dataset)
      expect(event.target_type).to eq('Dataset')
      expect(event.target_id).to eq(dataset.id)
    end

    it 'can have a query as target' do
      query = dataset.queries.create!(
        sql: "SELECT state, COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
        user: user
      )

      event = AuditEvent.create!(
        user: user,
        action: 'query_created',
        target: query
      )

      expect(event.target).to eq(query)
      expect(event.target_type).to eq('Query')
    end

    it 'can have nil target' do
      event = AuditEvent.create!(
        user: user,
        action: 'login'
      )

      expect(event.target).to be_nil
      expect(event.target_type).to be_nil
      expect(event.target_id).to be_nil
    end
  end

  describe 'metadata' do
    let(:organization) { Organization.create!(name: "Test Org") }
    let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }

    it 'stores metadata as JSON' do
      metadata = { query_id: 123, epsilon_consumed: 0.5, ip_address: '127.0.0.1' }

      event = AuditEvent.create!(
        user: user,
        action: 'query_executed',
        metadata: metadata
      )

      expect(event.metadata['query_id']).to eq(123)
      expect(event.metadata['epsilon_consumed']).to eq(0.5)
      expect(event.metadata['ip_address']).to eq('127.0.0.1')
    end

    it 'handles empty metadata' do
      event = AuditEvent.create!(
        user: user,
        action: 'login',
        metadata: {}
      )

      expect(event.metadata).to eq({})
    end
  end
end
