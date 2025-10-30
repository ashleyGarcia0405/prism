# frozen_string_literal: true

module Api
  module V1
    class RunsController < Api::BaseController
      def show
        run = Run.find(params[:id])

        render json: {
          id: run.id,
          query_id: run.query_id,
          status: run.status,
          backend_used: run.backend_used,
          result: run.result,
          epsilon_consumed: run.epsilon_consumed,
          execution_time_ms: run.execution_time_ms,
          proof_artifacts: run.proof_artifacts,
          error_message: run.error_message,
          created_at: run.created_at,
          updated_at: run.updated_at
        }, status: :ok
      end

      def result
        run = Run.find(params[:id])

        if run.completed?
          render json: {
            data: run.result,
            epsilon_consumed: run.epsilon_consumed
          }, status: :ok
        else
          render json: {
            status: run.status,
            message: 'Query execution not yet completed'
          }, status: :accepted
        end
      end
    end
  end
end
