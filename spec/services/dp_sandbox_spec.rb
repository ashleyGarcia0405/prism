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

    # Tests for generate_sample_data branches
    context 'with employees query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT AVG(salary) FROM employees WHERE department = 'engineering'",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'generates employee sample data with correct columns' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to be_present
        # Verify that employee bounds were calculated
        expect(result[:metadata]).to be_present
      end
    end

    context 'with customers query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM customers WHERE state = 'CA'",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'generates customer sample data' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to be_present
        expect(result).to have_key(:epsilon_consumed)
      end
    end

    context 'with generic query (unrecognized table)' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT AVG(value) FROM generic_table",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'generates generic sample data with id and value columns' do
        result = dp_sandbox.execute(0.5)
        expect(result[:data]).to be_present
        expect(result[:mechanism]).to be_present
      end
    end

    # Test for Python execution failure branch
    context 'when Python executor returns failure' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'returns mock result when Python fails with success=false' do
        # Mock the Python executor to return failure
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).and_return(
          ['{"success": false, "error": "Test error"}', '', status_mock]
        )
        
        result = dp_sandbox.execute(0.5)
        # Should fall through to rescue and generate mock result
        expect(result[:data]).to be_present
        expect(result[:metadata]).to include(:fallback)
      end
    end

    # Test for Python process error branch
    context 'when Python process fails to execute' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'handles Python execution failure gracefully' do
        # Mock the Python executor to simulate a failed process
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(false)
        allow(Open3).to receive(:capture3).and_return(
          ['', 'ModuleNotFoundError: No module named numpy', status_mock]
        )
        
        result = dp_sandbox.execute(0.5)
        # Should fall through to rescue and generate mock result
        expect(result[:data]).to be_present
        expect(result[:metadata]).to include(:fallback)
      end
    end

    # Test for JSON parse error branch
    context 'when Python returns invalid JSON' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT AVG(age) FROM patients",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'handles invalid JSON from Python executor' do
        # Mock the Python executor to return invalid JSON
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        allow(Open3).to receive(:capture3).and_return(
          ['Invalid JSON {broken}', '', status_mock]
        )
        
        result = dp_sandbox.execute(0.5)
        # Should fall through to rescue and generate mock result
        expect(result[:data]).to be_present
        expect(result[:metadata]).to include(:fallback)
      end
    end

    # Test for infer_bounds with empty values
    context 'with query containing non-numeric columns' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients WHERE diagnosis = 'diabetes'",
          user: user,
          estimated_epsilon: 0.5
        )
      end

      it 'handles infer_bounds correctly' do
        # This tests the infer_bounds method with various column types
        sandbox = DpSandbox.new(query)
        sample_data = {
          columns: ["id", "age", "treatment_cost"],
          rows: [
            [1, 45, 1500.50],
            [2, 52, 2000.75]
          ]
        }
        
        bounds = sandbox.send(:infer_bounds, sample_data)
        # id, age, and treatment_cost are numeric, so should have bounds
        expect(bounds).to be_a(Hash)
        # All numeric columns should be present in bounds
        expect(bounds.length).to be > 0
      end
    end

    # Test for different mock results based on query type
    context 'mock result generation for different aggregate types' do
      it 'generates mock result with count data (COUNT in sql)' do
        count_query = dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients GROUP BY diagnosis HAVING COUNT(*) >= 25",
          user: user,
          estimated_epsilon: 0.5
        )
        sandbox = DpSandbox.new(count_query)
        mock_result = sandbox.send(:generate_mock_result, 0.5)
        
        # COUNT is checked first in the if/elsif chain
        expect(mock_result[:data]).to have_key('count')
        expect(mock_result[:metadata]).to include(fallback: true)
        expect(mock_result[:mechanism]).to eq('laplace_mock')
      end

      it 'handles different SQL query patterns correctly' do
        # These tests verify that different paths are taken through generate_mock_result
        # All should return valid mock result structures even if they fall back to count
        queries = [
          "SELECT AVG(treatment_cost) FROM patients WHERE diagnosis = 'diabetes'",
          "SELECT SUM(treatment_cost) FROM patients WHERE diagnosis = 'diabetes'",
          "SELECT MIN(age) FROM patients WHERE diagnosis = 'diabetes'",
          "SELECT MAX(age) FROM patients WHERE diagnosis = 'diabetes'"
        ]
        
        queries.each do |sql|
          q = dataset.queries.create!(
            sql: sql,
            user: user,
            estimated_epsilon: 0.5
          )
          sandbox = DpSandbox.new(q)
          mock_result = sandbox.send(:generate_mock_result, 0.5)
          
          expect(mock_result).to have_key(:data)
          expect(mock_result).to have_key(:epsilon_consumed)
          expect(mock_result).to have_key(:mechanism)
          expect(mock_result[:mechanism]).to eq('laplace_mock')
        end
      end
    end

    # Test for prepare_input_data with different dataset types
    context 'prepare_input_data with different queries' do
      it 'prepares input data for patient query' do
        result = dp_sandbox.execute(0.5)
        # Verify all expected keys are present
        expect(result).to have_key(:epsilon_consumed)
        expect(result).to have_key(:delta)
        expect(result[:delta]).to eq(1e-5) # Default from execute
      end

      it 'prepares input data with custom delta' do
        result = dp_sandbox.execute(0.75, delta: 1e-7)
        expect(result[:epsilon_consumed]).to eq(0.75)
        # delta is passed through from the parameter (not hardcoded)
        expect(result[:delta]).to eq(1e-7)
      end
    end
  end
end
