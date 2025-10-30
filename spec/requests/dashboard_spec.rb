# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, password: 'password123') }

  before do
    # Log in the user
    post login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'GET /dashboard' do
    it 'renders successfully' do
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    context 'with datasets and queries' do
      let!(:dataset1) { create(:dataset, organization: organization) }
      let!(:dataset2) { create(:dataset, organization: organization) }
      let!(:query1) { create(:query, dataset: dataset1, user: user) }
      let!(:query2) { create(:query, dataset: dataset2, user: user) }

      before do
        # Update the automatically created privacy budgets
        dataset1.privacy_budget.update!(consumed_epsilon: 1.5)
        dataset2.privacy_budget.update!(consumed_epsilon: 0.8)
      end

      it 'displays datasets' do
        get dashboard_path
        expect(response.body).to include(dataset1.name)
        expect(response.body).to include(dataset2.name)
      end

      it 'calculates total epsilon consumed' do
        get dashboard_path
        expect(response.body).to match(/2\.3[0]?/)
      end

      it 'counts total queries' do
        get dashboard_path
        expect(response.body).to include('2')
      end
    end

    context 'with no datasets' do
      it 'shows zero epsilon consumed' do
        get dashboard_path
        expect(response.body).to match(/0\.0[0]?/)
      end

      it 'shows zero queries' do
        get dashboard_path
        expect(response.body).to include('0')
      end
    end
  end
end