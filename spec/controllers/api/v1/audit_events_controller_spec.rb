require 'rails_helper'

RSpec.describe Api::V1::AuditEventsController, type: :controller do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:token) { JsonWebToken.encode(user_id: user.id) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #index' do
    let!(:event1) do
      AuditEvent.create!(
        user: user,
        action: 'login',
        metadata: { ua: 'Mozilla' },
        created_at: 2.hours.ago
      )
    end

    let!(:event2) do
      AuditEvent.create!(
        user: user,
        action: 'dataset_created',
        target: dataset,
        metadata: { name: 'Patient Data' },
        created_at: 1.hour.ago
      )
    end

    let!(:event3) do
      AuditEvent.create!(
        user: user,
        action: 'query_executed',
        metadata: { query_id: 123 },
        created_at: 30.minutes.ago
      )
    end

    it 'returns all audit events' do
      get :index
      json = JSON.parse(response.body)
      expect(json['events'].size).to eq(3)
    end

    it 'returns 200 status' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'returns events in descending order by created_at' do
      get :index
      json = JSON.parse(response.body)
      expect(json['events'][0]['id']).to eq(event3.id)
      expect(json['events'][1]['id']).to eq(event2.id)
      expect(json['events'][2]['id']).to eq(event1.id)
    end

    it 'includes event details' do
      get :index
      json = JSON.parse(response.body)
      first_event = json['events'][0]
      expect(first_event['action']).to eq('query_executed')
      expect(first_event['user_id']).to eq(user.id)
      expect(first_event['metadata']).to be_present
    end

    it 'returns organization_id' do
      get :index
      json = JSON.parse(response.body)
      expect(json['organization_id']).to eq(organization.id)
    end

    it 'returns count of events' do
      get :index
      json = JSON.parse(response.body)
      expect(json['count']).to eq(3)
    end

    context 'with action filter' do
      it 'filters by event_action' do
        get :index, params: { event_action: 'login' }
        json = JSON.parse(response.body)
        expect(json['events'].size).to eq(1)
        expect(json['events'][0]['action']).to eq('login')
      end

      it 'returns only matching actions' do
        get :index, params: { event_action: 'dataset_created' }
        json = JSON.parse(response.body)
        expect(json['events'].size).to eq(1)
        expect(json['events'][0]['action']).to eq('dataset_created')
        expect(json['events'][0]['target_type']).to eq('Dataset')
      end
    end

    context 'with pagination' do
      before do
        # Create more events for pagination testing
        8.times do |i|
          AuditEvent.create!(
            user: user,
            action: 'login',
            metadata: { index: i },
            created_at: (i + 1).minutes.ago
          )
        end
      end

      it 'defaults to page 1 with page_size 50' do
        get :index
        json = JSON.parse(response.body)
        expect(json['count']).to be <= 50
      end

      it 'accepts page parameter' do
        get :index, params: { page: 2, page_size: 5 }
        json = JSON.parse(response.body)
        expect(json['events'].size).to be <= 5
      end

      it 'accepts page_size parameter' do
        get :index, params: { page_size: 2 }
        json = JSON.parse(response.body)
        expect(json['events'].size).to eq(2)
      end
    end

    context 'with organization_id parameter' do
      it 'uses specified organization_id' do
        get :index, params: { organization_id: organization.id }
        json = JSON.parse(response.body)
        expect(json['organization_id']).to eq(organization.id)
      end
    end

    context 'with different organization user' do
      let(:other_org) { Organization.create!(name: "Other Hospital") }
      let(:other_user) { other_org.users.create!(name: "Other User", email: "other@example.com", password: "password123") }

      let!(:other_event) do
        AuditEvent.create!(
          user: other_user,
          action: 'login',
          created_at: 1.hour.ago
        )
      end

      it 'does not return events from other organizations' do
        get :index
        json = JSON.parse(response.body)
        event_ids = json['events'].map { |e| e['id'] }
        expect(event_ids).not_to include(other_event.id)
      end
    end
  end
end