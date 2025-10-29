class QueryExecutionJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Run.find(run_id)
    run.update!(status: 'running')

    query = run.query
    dataset = query.dataset
    user    = run.user 
    reservation = nil

    # check and reserve privacy budget
    reservation = PrivacyBudgetService.check_and_reserve(
      dataset: dataset,
      epsilon_needed: query.estimated_epsilon
    )

    unless reservation[:success]
      run.update!(
        status: 'failed',
        error_message: reservation[:error]
      )
      AuditLogger.log(
        user: user,
        action: 'privacy_budget_exhausted',
        target: dataset,
        metadata: { query_id: query.id, needed: query.estimated_epsilon, error: reservation[:error] }
      )
      return
    end

    # execute query in DP Sandbox
    start_time = Time.now
    result = DpSandbox.new(query).execute(query.estimated_epsilon)
    execution_time = ((Time.now - start_time) * 1000).to_i

    # commit budget
    PrivacyBudgetService.commit(
      dataset: dataset,
      reservation_id: reservation[:reservation_id],
      actual_epsilon: result[:epsilon_consumed]
    )

    # store results
    run.update!(
      status: 'completed',
      backend_used: 'dp_sandbox',
      result: result[:data],
      epsilon_consumed: result[:epsilon_consumed],
      execution_time_ms: result[:execution_time_ms] || execution_time,
      proof_artifacts: {
        mechanism: result[:mechanism],
        noise_scale: result[:noise_scale],
        epsilon: result[:epsilon_consumed]
      }
    )
    AuditLogger.log(
      user: user,
      action: 'query_executed',
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
      status: 'failed',
      error_message: e.message
    )
    AuditLogger.log(
      user: user || query&.user,
      action: 'query_failed',
      target: run,
      metadata: { query_id: query&.id, dataset_id: dataset&.id, error: e.message }.compact
    )
    raise
  end
end
