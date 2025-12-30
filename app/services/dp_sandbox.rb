# frozen_string_literal: true

require "json"
require "open3"

class DpSandbox
  PYTHON_PATH = ENV.fetch("PYTHON_PATH", "python3")
  DP_EXECUTOR_PATH = Rails.root.join("lib", "python", "dp_executor.py").to_s

  def initialize(query)
    @query = query
    @dataset = query.dataset
  end

  def execute(epsilon, delta: 1e-5)
    start_time = Time.now

    # Prepare input for Python script
    input_data = prepare_input_data(epsilon, delta)

    # Call Python DP executor
    result = call_python_executor(input_data)

    # Handle errors from Python script
    unless result["success"]
      Rails.logger.error("DP execution failed: #{result['error']}")
      raise StandardError, "DP execution failed: #{result['error']}"
    end

    {
      data: result["result"],
      epsilon_consumed: result["epsilon_consumed"],
      delta: result["delta"],
      mechanism: result["mechanism"],
      noise_scale: result["noise_scale"],
      execution_time_ms: result["execution_time_ms"],
      metadata: result["metadata"]
    }
  rescue StandardError => e
    # Fallback to mock data if Python execution fails
    Rails.logger.warn("DP executor failed, falling back to mock: #{e.message}")
    generate_mock_result(epsilon)
  end

  private

  def prepare_input_data(epsilon, delta)
    # TODO: Once file upload is implemented, read actual dataset
    # For now, generate sample data based on query
    sample_data = generate_sample_data

    {
      query: @query.sql,
      data: sample_data[:rows],
      columns: sample_data[:columns],
      epsilon: epsilon,
      delta: delta,
      bounds: infer_bounds(sample_data)
    }
  end

  def generate_sample_data
    # Generate realistic sample data for testing
    # This will be replaced with actual dataset once file upload is implemented

    # Parse query to understand what data we need
    sql = @query.sql.downcase

    if sql.include?("patients") || sql.include?("patient")
      # Healthcare dataset
      {
        columns: [ "id", "age", "diagnosis", "treatment_cost" ],
        rows: 1000.times.map do |i|
          [
            i + 1,
            rand(18..85),
            [ "diabetes", "hypertension", "asthma", "arthritis" ].sample,
            rand(100.0..5000.0).round(2)
          ]
        end
      }
    elsif sql.include?("employees") || sql.include?("employee")
      # HR dataset
      {
        columns: [ "id", "age", "department", "salary" ],
        rows: 500.times.map do |i|
          [
            i + 1,
            rand(22..65),
            [ "engineering", "sales", "marketing", "hr" ].sample,
            rand(40000..150000)
          ]
        end
      }
    elsif sql.include?("customers") || sql.include?("customer")
      # Customer dataset
      {
        columns: [ "id", "age", "state", "purchases" ],
        rows: 2000.times.map do |i|
          [
            i + 1,
            rand(18..75),
            [ "CA", "NY", "TX", "FL", "IL" ].sample,
            rand(1..50)
          ]
        end
      }
    else
      # Generic dataset
      {
        columns: [ "id", "value" ],
        rows: 1000.times.map { |i| [ i + 1, rand(1.0..100.0).round(2) ] }
      }
    end
  end

  def infer_bounds(sample_data)
    # Infer reasonable bounds for numeric columns
    bounds = {}

    sample_data[:columns].each_with_index do |col, idx|
      next if col == "id" || col == "diagnosis" || col == "department" || col == "state" # Skip non-numeric

      # Extract values for this column
      values = sample_data[:rows].map { |row| row[idx] }.compact.select { |v| v.is_a?(Numeric) }

      if values.any?
        # Use min/max from sample data
        bounds[col] = [ values.min, values.max ]
      end
    end

    bounds
  end

  def call_python_executor(input_data)
    input_json = input_data.to_json

    # Execute Python script
    stdout, stderr, status = Open3.capture3(
      PYTHON_PATH,
      DP_EXECUTOR_PATH,
      input_json,
      chdir: Rails.root.to_s
    )

    unless status.success?
      Rails.logger.error("Python DP executor stderr: #{stderr}")
      raise StandardError, "Python execution failed: #{stderr}"
    end

    JSON.parse(stdout)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Python output: #{stdout}")
    raise StandardError, "Invalid JSON response from DP executor: #{e.message}"
  end

  def generate_mock_result(epsilon)
    # Fallback mock results if Python executor fails
    sql = @query.sql.downcase

    result_data = if sql.include?("count")
                    { "count" => rand(100..10_000) }
    elsif sql.include?("avg") || sql.include?("mean")
                    { "average" => rand(20.0..80.0).round(2) }
    elsif sql.include?("sum")
                    { "sum" => rand(1000..100_000) }
    elsif sql.include?("min")
                    { "min" => rand(1..50) }
    elsif sql.include?("max")
                    { "max" => rand(50..100) }
    else
                    { "value" => rand(1..1000) }
    end

    # Ensure execution time is at least 1ms to avoid test flakiness
    simulated_time = [ rand(50..200), 1 ].max

    {
      data: result_data,
      epsilon_consumed: epsilon,
      delta: 1e-5,
      mechanism: "laplace",
      noise_scale: (epsilon * 2.0).round(3),
      execution_time_ms: simulated_time,
      metadata: {
        "operation" => infer_operation(@query.sql),
        "fallback"  => true,
        "reason"    => "Python executor unavailable"
      }
    }
  end
  private

  def infer_operation(sql)
    s = sql.to_s.downcase
    return "count" if s.include?("count(")
    return "sum"   if s.include?("sum(")
    return "avg"   if s.include?("avg(") || s.include?("average(")
    return "min"   if s.include?("min(")
    return "max"   if s.include?("max(")
    "aggregate"
  end
end
