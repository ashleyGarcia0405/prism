# frozen_string_literal: true

class QueriesController < ApplicationController
  def index
    @queries = Query.joins(:dataset).where(datasets: { organization_id: current_user.organization_id }).order(created_at: :desc)
  end

  def show
    @query = Query.joins(:dataset).where(datasets: { organization_id: current_user.organization_id }).find(params[:id])
    @runs = @query.runs.order(created_at: :desc)
  end

  def new
    @query = Query.new
    @datasets = current_user.organization.datasets
    @query.dataset_id = params[:dataset_id] if params[:dataset_id]
  end

  def create
    dataset = current_user.organization.datasets.find(params[:query][:dataset_id])
    @query = dataset.queries.new(query_params)
    @query.user = current_user

    if @query.save
      redirect_to query_path(@query), notice: "Query created successfully!"
    else
      @datasets = current_user.organization.datasets
      render :new, status: :unprocessable_entity
    end
  end

  def execute
    @query = Query.joins(:dataset).where(datasets: { organization_id: current_user.organization_id }).find(params[:id])
    @run = @query.runs.create!(user: current_user, status: 'pending')
    QueryExecutionJob.perform_later(@run.id)

    redirect_to run_path(@run), notice: "Query execution started..."
  end

  private

  def query_params
    params.require(:query).permit(:sql, :dataset_id)
  end
end