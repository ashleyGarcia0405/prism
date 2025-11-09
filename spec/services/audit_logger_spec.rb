require 'rails_helper'

RSpec.describe AuditLogger do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Test Dataset") }

  describe '.log' do
    context 'with all parameters' do
      it 'creates an audit event' do
        expect {
          AuditLogger.log(
            user: user,
            action: 'query_created',
            target: dataset,
            metadata: { key: 'value' }
          )
        }.to change(AuditEvent, :count).by(1)
      end

      it 'sets the user' do
        AuditLogger.log(
          user: user,
          action: 'query_created',
          target: dataset,
          metadata: {}
        )

        event = AuditEvent.last
        expect(event.user_id).to eq(user.id)
      end

      it 'sets the action' do
        AuditLogger.log(
          user: user,
          action: 'query_created',
          target: dataset,
          metadata: {}
        )

        event = AuditEvent.last
        expect(event.action).to eq('query_created')
      end

      it 'sets the target type and id' do
        AuditLogger.log(
          user: user,
          action: 'query_created',
          target: dataset,
          metadata: {}
        )

        event = AuditEvent.last
        expect(event.target_type).to eq('Dataset')
        expect(event.target_id).to eq(dataset.id)
      end

      it 'sets the metadata' do
        metadata = { query_id: 123, epsilon: 0.5 }

        AuditLogger.log(
          user: user,
          action: 'query_executed',
          target: dataset,
          metadata: metadata
        )

        event = AuditEvent.last
        expect(event.metadata).to eq(metadata.stringify_keys)
      end
    end

    context 'without target' do
      it 'creates audit event with nil target' do
        expect {
          AuditLogger.log(
            user: user,
            action: 'login',
            metadata: { ip: '127.0.0.1' }
          )
        }.to change(AuditEvent, :count).by(1)

        event = AuditEvent.last
        expect(event.target_type).to be_nil
        expect(event.target_id).to be_nil
      end
    end

    context 'with different actions' do
      it 'logs login action' do
        AuditLogger.log(user: user, action: 'login')
        expect(AuditEvent.last.login_action?).to be true
      end

      it 'logs dataset_created action' do
        AuditLogger.log(user: user, action: 'dataset_created', target: dataset)
        expect(AuditEvent.last.dataset_created_action?).to be true
      end

      it 'logs query_created action' do
        AuditLogger.log(user: user, action: 'query_created')
        expect(AuditEvent.last.query_created_action?).to be true
      end

      it 'logs query_executed action' do
        AuditLogger.log(user: user, action: 'query_executed')
        expect(AuditEvent.last.query_executed_action?).to be true
      end

      it 'logs query_failed action' do
        AuditLogger.log(user: user, action: 'query_failed')
        expect(AuditEvent.last.query_failed_action?).to be true
      end

      it 'logs privacy_budget_exhausted action' do
        AuditLogger.log(user: user, action: 'privacy_budget_exhausted', target: dataset)
        expect(AuditEvent.last.privacy_budget_exhausted_action?).to be true
      end
    end
  end
end
