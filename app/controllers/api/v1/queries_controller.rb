# frozen_string_literal: true

module Api
  module V1
    class QueriesController < Api::BaseController
      def create
        dataset = Dataset.find(params[:query][:dataset_id])
        query = dataset.queries.new(query_params.merge(user: current_user))

        if query.save
          AuditLogger.log(
            user: current_user,
            action: "query_created",
            target: query,
            metadata: {
              dataset_id: query.dataset_id,
              estimated_epsilon: query.estimated_epsilon,
              sql: query.sql,
              backend: query.backend
            }
          )
          render json: {
            id: query.id,
            sql: query.sql,
            dataset_id: query.dataset_id,
            estimated_epsilon: query.estimated_epsilon,
            backend: query.backend,
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
          backend: query.backend,
          created_at: query.created_at
        }, status: :ok
      end

      def validate
        sql = params[:sql]

        unless sql
          return render json: {
            valid: false,
            errors: [ "SQL parameter is required" ]
          }, status: :bad_request
        end

        validation = QueryValidator.validate(sql)

        if validation[:valid]
          render json: {
            valid: true,
            estimated_epsilon: validation[:estimated_epsilon],
            estimated_time_seconds: 2
          }, status: :ok
        else
          render json: {
            valid: false,
            errors: validation[:errors]
          }, status: :unprocessable_entity
        end
      end

      def execute
        query = Query.find(params[:id])

        # Validate backend is available
        unless BackendRegistry.backend_available?(query.backend)
          backend_config = BackendRegistry.get_backend(query.backend)
          return render json: {
            error: "Backend '#{query.backend}' is not available",
            reason: backend_config[:unavailable_reason],
            alternatives: backend_config[:alternatives]
          }, status: :unprocessable_entity
        end

        # create run record
        run = query.runs.create!(
          status: "pending",
          user: current_user
        )

        # enqueue background job
        QueryExecutionJob.perform_later(run.id)

        render json: {
          run_id: run.id,
          status: "pending",
          backend: query.backend,
          estimated_time_seconds: 2,
          poll_url: api_v1_run_url(run)
        }, status: :accepted
      rescue BackendRegistry::BackendNotFoundError => e
        render json: { error: e.message }, status: :bad_request
      end

      def backends
        render json: BackendRegistry.all_backends, status: :ok
      end

      private

      def query_params
        params.require(:query).permit(:sql, :dataset_id, :backend, :delta)
      end
    end
  end
end
