# frozen_string_literal: true

class DatasetsController < ApplicationController
  def index
    @datasets = current_user.organization.datasets.includes(:privacy_budget).order(created_at: :desc)
  end

  def show
    @dataset = current_user.organization.datasets.find(params[:id])
    @budget = @dataset.privacy_budget
    @queries = @dataset.queries.includes(:runs).order(created_at: :desc).limit(10)
  end

  def new
    @dataset = Dataset.new
  end

  def create
    @dataset = current_user.organization.datasets.new(dataset_params)

    if @dataset.save
      redirect_to dataset_path(@dataset), notice: "Dataset created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def dataset_params
    params.require(:dataset).permit(:name, :description)
  end
end