require 'rails_helper'

RSpec.describe DpSandbox do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:query) do
    dataset.queries.create!(
      sql: "SELECT AVG(age) FROM patients",
      user: user,
      estimated_epsilon: 0.5
    )
  end
  let(:dp_sandbox) { DpSandbox.new(query) }

  describe '#execute' do
    it 'returns a hash with data' do
      result = dp_sandbox.execute(0.5)
      expect(result).to be_a(Hash)
      expect(result[:data]).to be_present
    end

    it 'returns epsilon_consumed' do
      result = dp_sandbox.execute(0.5)
      expect(result[:epsilon_consumed]).to eq(0.5)
    end

    it 'returns delta' do
      result = dp_sandbox.execute(0.5, delta: 1e-5)
      expect(result[:delta]).to eq(1e-5)
    end

    it 'returns mechanism type' do
      result = dp_sandbox.execute(0.5)
      expect(result[:mechanism]).to eq('laplace')
    end

    it 'returns noise_scale' do
      result = dp_sandbox.execute(0.5)
      expect(result[:noise_scale]).to be_present
    end

    it 'returns execution_time_ms' do
      result = dp_sandbox.execute(0.5)
      expect(result[:execution_time_ms]).to be_present
      expect(result[:execution_time_ms]).to be >= 0
    end

    it 'returns metadata' do
      result = dp_sandbox.execute(0.5)
      expect(result[:metadata]).to be_present
      expect(result[:metadata]).to include('operation')
    end

    context 'with COUNT query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns count result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to have_key('count')
        expect(result[:data]['count']).to be >= 0
      end
    end

    context 'with SUM query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT SUM(age) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns sum result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to have_key('sum')
        expect(result[:data]['sum']).to be_a(Numeric)
      end
    end

    context 'with AVG query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT AVG(age) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns average result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to have_key('average')
        expect(result[:data]['average']).to be_a(Numeric)
      end
    end

    context 'with MIN query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT MIN(age) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns min result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to have_key('min')
        expect(result[:data]['min']).to be_a(Numeric)
      end
    end

    context 'with MAX query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT MAX(age) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns max result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to have_key('max')
        expect(result[:data]['max']).to be_a(Numeric)
      end
    end

    context 'with different epsilon values' do
      it 'handles very small epsilon' do
        result = dp_sandbox.execute(0.01)
        expect(result[:epsilon_consumed]).to eq(0.01)
      end

      it 'handles large epsilon' do
        result = dp_sandbox.execute(10.0)
        expect(result[:epsilon_consumed]).to eq(10.0)
      end

      it 'handles zero epsilon' do
        result = dp_sandbox.execute(0.0)
        expect(result[:epsilon_consumed]).to eq(0.0)
      end
    end

    context 'with different delta values' do
      it 'handles custom delta' do
        result = dp_sandbox.execute(0.5, delta: 1e-10)
        expect(result[:delta]).to eq(1e-10)
      end

      it 'handles very large delta' do
        result = dp_sandbox.execute(0.5, delta: 0.1)
        expect(result[:delta]).to eq(0.1)
      end
    end

    context 'with Python executor failures' do
      before do
        allow(Open3).to receive(:capture3).and_raise(StandardError, "Python not found")
      end

      it 'falls back to mock result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:metadata]).to include('fallback' => true)
      end

      it 'logs warning about fallback' do
        expect(Rails.logger).to receive(:warn).with(/falling back to mock/)
        dp_sandbox.execute(0.5)
      end

      it 'still returns valid result structure' do
        result = dp_sandbox.execute(0.5)
        expect(result).to have_key(:data)
        expect(result).to have_key(:epsilon_consumed)
        expect(result).to have_key(:mechanism)
      end
    end

    context 'with invalid Python output' do
      before do
        allow(Open3).to receive(:capture3).and_return(
          ["invalid json", "", double(success?: true)]
        )
      end

      it 'raises error and falls back to mock' do
        result = dp_sandbox.execute(0.5)
        expect(result[:metadata]['fallback']).to be true
      end
    end

    context 'with Python execution error' do
      before do
        status = double(success?: false)
        allow(Open3).to receive(:capture3).and_return(
          ["", "Python error occurred", status]
        )
      end

      it 'logs error message' do
        expect(Rails.logger).to receive(:error).with(/Python DP executor stderr/)
        dp_sandbox.execute(0.5)
      end

      it 'falls back to mock result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:metadata]).to include('fallback' => true)
      end
    end

    context 'with successful Python output' do
      before do
        python_result = {
          "success" => true,
          "result" => { "average" => 45.5 },
          "epsilon_consumed" => 0.5,
          "delta" => 1e-5,
          "mechanism" => "laplace",
          "noise_scale" => 1.0,
          "execution_time_ms" => 100,
          "metadata" => { "operation" => "avg" }
        }
        allow(Open3).to receive(:capture3).and_return(
          [python_result.to_json, "", double(success?: true)]
        )
      end

      it 'returns Python result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]["average"]).to eq(45.5)
        expect(result[:metadata]["fallback"]).to be_nil
      end
    end

    context 'with Python returning error' do
      before do
        python_result = {
          "success" => false,
          "error" => "Division by zero in query"
        }
        allow(Open3).to receive(:capture3).and_return(
          [python_result.to_json, "", double(success?: true)]
        )
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/DP execution failed/)
        dp_sandbox.execute(0.5)
      end

      it 'falls back to mock result' do
        result = dp_sandbox.execute(0.5)
        expect(result[:metadata]['fallback']).to be true
      end
    end
  end

  describe '#generate_sample_data' do
    it 'generates data for patients query' do
      result = dp_sandbox.send(:generate_sample_data)
      expect(result[:columns]).to include("age", "diagnosis")
      expect(result[:rows]).not_to be_empty
    end

    context 'with employees dataset' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT AVG(salary) FROM employees",
          user: user,
          estimated_epsilon: 0.5
        )
      end
      let(:dp_sandbox) { DpSandbox.new(query) }

      it 'generates employee data' do
        result = dp_sandbox.send(:generate_sample_data)
        expect(result[:columns]).to include("salary", "department")
      end
    end

    context 'with customers dataset' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM customers GROUP BY state HAVING COUNT(*) >= 25",
          user: user,
          estimated_epsilon: 0.5
        )
      end
      let(:dp_sandbox) { DpSandbox.new(query) }

      it 'generates customer data' do
        result = dp_sandbox.send(:generate_sample_data)
        expect(result[:columns]).to include("state", "purchases")
      end
    end

    context 'with unknown dataset type' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM unknown_table",
          user: user,
          estimated_epsilon: 0.5
        )
      end
      let(:dp_sandbox) { DpSandbox.new(query) }

      it 'generates generic data' do
        result = dp_sandbox.send(:generate_sample_data)
        expect(result[:columns]).to include("id", "value")
      end
    end
  end

  describe '#infer_bounds' do
    let(:sample_data) do
      {
        columns: ["id", "age", "salary"],
        rows: [
          [1, 25, 50000],
          [2, 35, 75000],
          [3, 45, 100000]
        ]
      }
    end

    it 'infers bounds for numeric columns' do
      bounds = dp_sandbox.send(:infer_bounds, sample_data)
      expect(bounds["age"]).to eq([25, 45])
      expect(bounds["salary"]).to eq([50000, 100000])
    end

    it 'skips id column' do
      bounds = dp_sandbox.send(:infer_bounds, sample_data)
      expect(bounds).not_to have_key("id")
    end

    it 'handles empty data' do
      empty_data = { columns: ["id", "age"], rows: [] }
      bounds = dp_sandbox.send(:infer_bounds, empty_data)
      expect(bounds).to eq({})
    end

    it 'handles non-numeric columns' do
      mixed_data = {
        columns: ["id", "name", "age"],
        rows: [
          [1, "Alice", 25],
          [2, "Bob", 35]
        ]
      }
      bounds = dp_sandbox.send(:infer_bounds, mixed_data)
      expect(bounds).not_to have_key("name")
      expect(bounds).to have_key("age")
    end
  end

  describe '#infer_operation' do
    it 'detects COUNT operation' do
      op = dp_sandbox.send(:infer_operation, "SELECT COUNT(*) FROM table")
      expect(op).to eq("count")
    end

    it 'detects SUM operation' do
      op = dp_sandbox.send(:infer_operation, "SELECT SUM(age) FROM table")
      expect(op).to eq("sum")
    end

    it 'detects AVG operation' do
      op = dp_sandbox.send(:infer_operation, "SELECT AVG(age) FROM table")
      expect(op).to eq("avg")
    end

    it 'detects MIN operation' do
      op = dp_sandbox.send(:infer_operation, "SELECT MIN(age) FROM table")
      expect(op).to eq("min")
    end

    it 'detects MAX operation' do
      op = dp_sandbox.send(:infer_operation, "SELECT MAX(age) FROM table")
      expect(op).to eq("max")
    end

    it 'handles case-insensitive detection' do
      op = dp_sandbox.send(:infer_operation, "select count(*) from table")
      expect(op).to eq("count")
    end

    it 'defaults to aggregate for unknown operations' do
      op = dp_sandbox.send(:infer_operation, "SELECT STDDEV(age) FROM table")
      expect(op).to eq("aggregate")
    end

    it 'handles nil SQL' do
      op = dp_sandbox.send(:infer_operation, nil)
      expect(op).to eq("aggregate")
    end

    it 'handles empty SQL' do
      op = dp_sandbox.send(:infer_operation, "")
      expect(op).to eq("aggregate")
    end
  end

  describe '#prepare_input_data' do
    it 'includes query SQL' do
      input = dp_sandbox.send(:prepare_input_data, 0.5, 1e-5)
      expect(input[:query]).to eq(query.sql)
    end

    it 'includes epsilon' do
      input = dp_sandbox.send(:prepare_input_data, 0.5, 1e-5)
      expect(input[:epsilon]).to eq(0.5)
    end

    it 'includes delta' do
      input = dp_sandbox.send(:prepare_input_data, 0.5, 1e-5)
      expect(input[:delta]).to eq(1e-5)
    end

    it 'includes sample data' do
      input = dp_sandbox.send(:prepare_input_data, 0.5, 1e-5)
      expect(input[:data]).not_to be_empty
      expect(input[:columns]).not_to be_empty
    end

    it 'includes bounds' do
      input = dp_sandbox.send(:prepare_input_data, 0.5, 1e-5)
      expect(input[:bounds]).to be_a(Hash)
    end
  end

  describe 'error resilience' do
    it 'never raises unhandled exceptions with valid query' do
      # Should always return a result, even if Python fails
      expect { dp_sandbox.execute(0.5) }.not_to raise_error
    end

    it 'raises NoMethodError when query SQL is nil' do
      # This is an edge case - nil SQL should be caught at validation
      allow(query).to receive(:sql).and_return(nil)
      expect { dp_sandbox.execute(0.5) }.to raise_error(NoMethodError)
    end

    it 'handles missing dataset without crashing' do
      # This is an edge case - missing dataset should be caught earlier in production
      # The DpSandbox generates sample data internally and doesn't actually query the dataset
      # So it can complete execution even with nil dataset
      allow(query).to receive(:dataset).and_return(nil)

      # Should not raise an error during execution (uses mock data)
      expect { dp_sandbox.execute(0.5) }.not_to raise_error

      # Should still return a valid result
      result = dp_sandbox.execute(0.5)
      expect(result).to have_key(:data)
      expect(result).to have_key(:epsilon_consumed)
    end
  end
end
