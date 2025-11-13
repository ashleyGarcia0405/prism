# frozen_string_literal: true

class DatasetsController < ApplicationController
  def index
    @datasets = current_user.organization.datasets.includes(:privacy_budget).order(created_at: :desc)
  end

  def show
    @dataset = current_user.organization.datasets.find(params[:id])
    @budget = @dataset.privacy_budget
    @queries = @dataset.queries.includes(:runs).order(created_at: :desc).limit(10)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @dataset.id,
          name: @dataset.name,
          table_name: @dataset.table_name,
          columns: @dataset.columns
        }
      end
    end
  end

  def new
    @dataset = Dataset.new
  end

  def create
    @dataset = current_user.organization.datasets.new(dataset_params)

    if @dataset.save
      # Check if a file was uploaded during creation
      if params[:file].present?
        begin
          file = params[:file]
          io = file.respond_to?(:tempfile) ? file.tempfile : file
          filename = file.respond_to?(:original_filename) ? file.original_filename : "upload.csv"

          result = DatasetIngestor.new(dataset: @dataset, io: io, filename: filename).call

          redirect_to dataset_path(@dataset),
                      notice: "Dataset created and file uploaded! #{result.row_count} rows imported with #{result.columns.size} columns."
        rescue ArgumentError => e
          redirect_to dataset_path(@dataset), alert: "Dataset created but upload failed: #{e.message}"
        rescue StandardError => e
          Rails.logger.error("Dataset upload error: #{e.message}\n#{e.backtrace.join("\n")}")
          redirect_to dataset_path(@dataset), alert: "Dataset created but upload failed: #{e.message}"
        end
      else
        redirect_to dataset_path(@dataset), notice: "Dataset created successfully! Upload your data file when ready."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def upload
    @dataset = current_user.organization.datasets.find(params[:id])

    file = params[:file]

    if file.blank?
      redirect_to dataset_path(@dataset), alert: "Please select a file to upload"
      return
    end

    begin
      io = file.respond_to?(:tempfile) ? file.tempfile : file
      filename = file.respond_to?(:original_filename) ? file.original_filename : "upload.csv"

      result = DatasetIngestor.new(dataset: @dataset, io: io, filename: filename).call

      redirect_to dataset_path(@dataset),
                  notice: "File uploaded successfully! #{result.row_count} rows imported with #{result.columns.size} columns."
    rescue ArgumentError => e
      redirect_to dataset_path(@dataset), alert: "Upload failed: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("Dataset upload error: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_to dataset_path(@dataset), alert: "Upload failed: #{e.message}"
    end
  end

  private

  def dataset_params
    params.require(:dataset).permit(:name, :description)
  end
end
