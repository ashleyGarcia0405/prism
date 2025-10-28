class DpSandbox
  def initialize(query)
    @query = query
  end

  def execute(epsilon)
    # MVP: Return mocked results with fake noise
    # In production, this would call Python diffprivlib or something like that idk yet

    sql = @query.sql.downcase
    start_time = Time.now

    result_data = generate_mock_result(sql)
    execution_time = ((Time.now - start_time) * 1000).to_i

    # Add fake noise proportional to epsilon
    noise_scale = (epsilon * 2.0).round(3)

    {
      data: result_data,
      epsilon_consumed: epsilon,
      mechanism: 'laplace',
      noise_scale: noise_scale,
      execution_time_ms: execution_time + rand(50..200) # Simulate processing time
    }
  end

  private

  def generate_mock_result(sql)
    # generate fake results based on SQL query type
    if sql.include?('count')
      { 'count' => rand(100..10000) }
    elsif sql.include?('avg') || sql.include?('mean')
      { 'average' => rand(20.0..80.0).round(2) }
    elsif sql.include?('sum')
      { 'sum' => rand(1000..100000) }
    elsif sql.include?('min')
      { 'min' => rand(1..50) }
    elsif sql.include?('max')
      { 'max' => rand(50..100) }
    else
      # Default aggregate result
      { 'value' => rand(1..1000) }
    end
  end
end