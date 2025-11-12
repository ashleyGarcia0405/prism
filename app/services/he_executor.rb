# frozen_string_literal: true

require "json"
require "open3"

# HeExecutor executes queries using Homomorphic Encryption via TenSEAL
# Supports COUNT and SUM operations on encrypted data
class HeExecutor
  PYTHON_PATH = ENV.fetch("PYTHON_PATH", "python3")
  HE_EXECUTOR_PATH = Rails.root.join("lib", "python", "he_executor.py").to_s

  attr_reader :query, :dataset

  def initialize(query)
    @query = query
    @dataset = query.dataset
  end

  def execute
    start_time = Time.now

    # Prepare input for Python HE executor
    input_data = prepare_input_data

    # Call Python HE executor
    result = call_python_executor(input_data)

    # Handle errors
    unless result["success"]
      Rails.logger.error("HE execution failed: #{result['error']}")
      raise StandardError, "HE execution failed: #{result['error']}"
    end

    {
      data: result["result"],
      epsilon_consumed: 0.0, # HE doesn't consume epsilon
      delta: 0.0,
      mechanism: result["mechanism"],
      noise_scale: 0.0,
      execution_time_ms: result["execution_time_ms"],
      proof_artifacts: {
        mechanism: "homomorphic_encryption",
        encryption_scheme: result.dig("metadata", "encryption_scheme"),
        poly_modulus_degree: result.dig("metadata", "poly_modulus_degree"),
        records_encrypted: result.dig("metadata", "records_encrypted"),
        metadata: result["metadata"]
      },
      metadata: result["metadata"]
    }
  rescue StandardError => e
    Rails.logger.error("HE executor failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def prepare_input_data
    # Generate sample data (will be replaced with real dataset when file upload is implemented)
    sample_data = generate_sample_data

    {
      query: @query.sql,
      data: sample_data[:rows],
      columns: sample_data[:columns],
      bounds: infer_bounds(sample_data)
    }
  end

  def generate_sample_data
    # Same as DpSandbox for consistency
    sql = @query.sql.downcase

    if sql.include?("patients") || sql.include?("patient")
      {
        columns: [ "id", "age", "diagnosis", "treatment_cost" ],
        rows: 1000.times.map do |i|
          [
            i + 1,
            rand(18..85),
            [ "diabetes", "hypertension", "asthma", "arthritis" ].sample,
            rand(100..5000)
          ]
        end
      }
    elsif sql.include?("salary") || sql.include?("employee")
      {
        columns: [ "id", "salary", "department", "years_experience" ],
        rows: 1000.times.map do |i|
          [
            i + 1,
            rand(30000..150000),
            [ "Engineering", "Sales", "Marketing", "HR" ].sample,
            rand(0..25)
          ]
        end
      }
    else
      {
        columns: [ "id", "value" ],
        rows: 1000.times.map { |i| [ i + 1, rand(1..100) ] }
      }
    end
  end

  def infer_bounds(sample_data)
    bounds = {}

    sample_data[:columns].each_with_index do |col, idx|
      next if col == "id" || col == "diagnosis" || col == "department"

      values = sample_data[:rows].map { |row| row[idx] }.compact.select { |v| v.is_a?(Numeric) }

      if values.any?
        bounds[col] = [ values.min, values.max ]
      end
    end

    bounds
  end

  def call_python_executor(input_data)
    input_json = input_data.to_json

    stdout, stderr, status = Open3.capture3(
      PYTHON_PATH,
      HE_EXECUTOR_PATH,
      input_json,
      chdir: Rails.root.to_s
    )

    unless status.success?
      Rails.logger.error("Python HE executor stderr: #{stderr}")
      raise StandardError, "Python execution failed: #{stderr}"
    end

    JSON.parse(stdout)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Python output: #{stdout}")
    Rails.logger.error("Python stderr: #{stderr}")
    raise StandardError, "Invalid JSON response from HE executor: #{e.message}"
  end
end
