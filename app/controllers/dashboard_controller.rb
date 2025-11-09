# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @datasets = current_user.organization.datasets.includes(:privacy_budget)
    @recent_queries = current_user.organization.datasets.joins(:queries).merge(Query.order(created_at: :desc)).limit(10)
    @total_epsilon_consumed = @datasets.sum { |d| d.privacy_budget&.consumed_epsilon || 0 }
    @total_queries = Query.joins(:dataset).where(datasets: { organization_id: current_user.organization_id }).count
  end
end
