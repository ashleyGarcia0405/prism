# frozen_string_literal: true

class RunsController < ApplicationController
  def show
    @run = Run.joins(query: :dataset)
               .where(datasets: { organization_id: current_user.organization_id })
               .find(params[:id])
    @query = @run.query
    @dataset = @query.dataset
  end
end
