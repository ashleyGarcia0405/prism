# frozen_string_literal: true

module Api
  module V1
    class DatasetsController < Api::BaseController
      def index
        organization = Organization.find(params[:organization_id])
        datasets = organization.datasets

        render json: {
          datasets: datasets.map do |dataset|
            {
              id: dataset.id,
              name: dataset.name,
              organization_id: dataset.organization_id,
              created_at: dataset.created_at
            }
          end
        }, status: :ok
      end

      def create
        organization = Organization.find(params[:organization_id])
        dataset = organization.datasets.new(dataset_params)
        if dataset.save
          AuditLogger.log(user: current_user, action: "dataset_created", target: dataset, metadata: { name: dataset.name })
          render json: {
            id: dataset.id,
            name: dataset.name,
            organization_id: dataset.organization_id,
            created_at: dataset.created_at
          }, status: :created
        else
          render json: { errors: dataset.errors.full_messages }, status: :unprocessable_entity
        end
      end


      def upload
        organization = Organization.find(params[:organization_id])
        dataset = organization.datasets.find(params[:id])

        # Accept either top-level :file or nested :dataset[:file]
        file = params[:file] || params.dig(:dataset, :file)
        return render json: { error: "file is required" }, status: :bad_request if file.blank?

        io  = file.respond_to?(:tempfile) ? file.tempfile : file
        filename = file.respond_to?(:original_filename) ? file.original_filename : "upload.csv"

        result = DatasetIngestor.new(dataset: dataset, io: io, filename: filename).call

        AuditLogger.log(
          user: current_user,
          action: 'dataset_uploaded',
          target: dataset,
          metadata: { filename: dataset.original_filename, rows: result.row_count }
        )

        render json: {
          dataset_id: dataset.id,
          table: dataset.table_name,
          row_count: result.row_count,
          columns: result.columns
        }, status: :ok
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_content
      end



      def budget
        dataset = Dataset.find(params[:id])
        budget = dataset.privacy_budget

        unless budget
          return render json: { error: "Privacy budget not found for this dataset" }, status: :not_found
        end

        render json: {
          dataset_id: dataset.id,
          total_epsilon: budget.total_epsilon,
          consumed_epsilon: budget.consumed_epsilon,
          reserved_epsilon: budget.reserved_epsilon,
          remaining_epsilon: budget.remaining_epsilon
        }, status: :ok
      end

      private

      def dataset_params
        params.require(:dataset).permit(:name)
      end
    end
  end
end
