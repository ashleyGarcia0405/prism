class QueryExecutionJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Run.find(run_id)
    run.update!(status: "running")

    query = run.query
    dataset = query.dataset
    user    = run.user
    reservation = nil

    # check and reserve privacy budget (only for DP backend)
    if query.backend == "dp_sandbox"
      reservation = PrivacyBudgetService.check_and_reserve(
        dataset: dataset,
        epsilon_needed: query.estimated_epsilon
      )

      unless reservation[:success]
        run.update!(
          status: "failed",
          error_message: reservation[:error]
        )
        AuditLogger.log(
          user: user,
          action: "privacy_budget_exhausted",
          target: dataset,
          metadata: { query_id: query.id, needed: query.estimated_epsilon, error: reservation[:error] }
        )
        return
      end
    end

    # Get executor for the query's backend
    executor = BackendRegistry.get_executor(query.backend, query)

    # execute query with appropriate backend
    start_time = Time.now
    result = case query.backend
    when "dp_sandbox"
      executor.execute(query.estimated_epsilon, delta: query.delta)
    when "mpc_backend"
      # MPC backend doesn't use epsilon/delta
      executor.execute
    when "he_backend"
      # HE backend doesn't use epsilon/delta
      executor.execute
    else
      raise "Unknown backend: #{query.backend}"
    end
    execution_time = ((Time.now - start_time) * 1000).to_i
    execution_time = 1 if execution_time == 0

    # commit budget (only for DP backend)
    if query.backend == "dp_sandbox" && reservation && reservation[:success]
      PrivacyBudgetService.commit(
        dataset: dataset,
        reservation_id: reservation[:reservation_id],
        actual_epsilon: result[:epsilon_consumed]
      )
    end

    # store results
    run.update!(
      status: "completed",
      backend_used: query.backend,
      result: result[:data] || result[:result],  # Support both :data and :result keys
      epsilon_consumed: result[:epsilon_consumed],
      delta_consumed: result[:delta],
      execution_time_ms: result[:execution_time_ms] || execution_time,
      proof_artifacts: result[:proof_artifacts] || {
        mechanism: result[:mechanism],
        noise_scale: result[:noise_scale],
        epsilon: result[:epsilon_consumed],
        delta: result[:delta],
        metadata: result[:metadata]
      }
    )
    AuditLogger.log(
      user: user,
      action: "query_executed",
      target: run,
      metadata: { query_id: query.id, dataset_id: dataset.id, epsilon_consumed: run.epsilon_consumed }
    )

  rescue => e
    # rollback budget reservation on error
    if reservation && reservation[:success]
      PrivacyBudgetService.rollback(
        dataset: dataset,
        reservation_id: reservation[:reservation_id],
        reserved_epsilon: query.estimated_epsilon
      )
    end

    run.update!(
      status: "failed",
      error_message: e.message,
      result: nil  # Clear any invalid result data
    )
    AuditLogger.log(
      user: user || query&.user,
      action: "query_failed",
      target: run,
      metadata: { query_id: query&.id, dataset_id: dataset&.id, error: e.message }.compact
    )
    raise
  end
end
