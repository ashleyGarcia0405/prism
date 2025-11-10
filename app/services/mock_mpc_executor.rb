# frozen_string_literal: true

# MockMpcExecutor simulates multi-party computation for collaborative queries
# This is a mock implementation that returns realistic-looking results
class MockMpcExecutor
  attr_reader :query

  def initialize(query)
    @query = query
  end

  def execute
    start_time = Time.now

    # Parse SQL to extract operation type
    sql_lower = query.sql.downcase
    operation = extract_operation(sql_lower)

    # Generate mock result based on operation
    result_data = case operation
    when :count
      generate_count_result
    when :sum
      generate_sum_result
    when :avg
      generate_avg_result
    else
      raise "Unsupported operation for MPC backend: #{operation}"
    end

    execution_time_ms = ((Time.now - start_time) * 1000).to_i

    {
      data: result_data,
      epsilon_consumed: nil, # MPC doesn't use epsilon
      delta: nil,
      mechanism: "secret_sharing",
      execution_time_ms: execution_time_ms,
      proof_artifacts: {
        protocol: "shamirs_secret_sharing",
        num_parties: 3,
        threshold: 2,
        shares_distributed: true,
        reconstruction_successful: true,
        mocked: true
      },
      metadata: {
        backend: "mpc_backend",
        mocked: true,
        note: "This is a simulated MPC result for demonstration purposes"
      }
    }
  end

  private

  def extract_operation(sql)
    if sql.match?(/count\s*\(/i)
      :count
    elsif sql.match?(/sum\s*\(/i)
      :sum
    elsif sql.match?(/avg\s*\(/i)
      :avg
    else
      :unknown
    end
  end

  def generate_count_result
    # Generate a realistic count value
    base_count = rand(1000..10000)

    { count: base_count }
  end

  def generate_sum_result
    # Generate a realistic sum value
    base_sum = rand(100000..1000000).to_f.round(2)

    { sum: base_sum }
  end

  def generate_avg_result
    # Generate a realistic average value
    base_avg = rand(10.0..100.0).round(2)

    { avg: base_avg }
  end
end
