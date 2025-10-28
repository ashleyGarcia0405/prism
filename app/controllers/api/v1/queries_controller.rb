# frozen_string_literal: true

module Api
  module V1
    class QueriesController < Api::BaseController
      def create
        dataset = Dataset.find(params[:query][:dataset_id])
        query = dataset.queries.new(query_params.merge(user: current_user))

        if query.save
          render json: {
            id: query.id,
            sql: query.sql,
            dataset_id: query.dataset_id,
            estimated_epsilon: query.estimated_epsilon,
            created_at: query.created_at
          }, status: :created
        else
          render json: { errors: query.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        query = Query.find(params[:id])
        render json: {
          id: query.id,
          sql: query.sql,
          dataset_id: query.dataset_id,
          estimated_epsilon: query.estimated_epsilon,
          created_at: query.created_at
        }, status: :ok
      end

      def execute
        query = Query.find(params[:id])

        # create run record
        run = query.runs.create!(
          status: 'pending',
          user: current_user
        )

        # enqueue background job
        QueryExecutionJob.perform_later(run.id)

        render json: {
          run_id: run.id,
          status: 'pending',
          backend: 'dp_sandbox',
          estimated_time_seconds: 2,
          poll_url: api_v1_run_url(run)
        }, status: :accepted
      end

      private

      def query_params
        params.require(:query).permit(:sql, :dataset_id)
      end
    end
  end
end
