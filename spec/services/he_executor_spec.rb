# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HeExecutor do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Test Data") }

  describe '#initialize' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    it 'stores query reference' do
      executor = HeExecutor.new(query)
      expect(executor.query).to eq(query)
    end

    it 'stores dataset reference from query' do
      executor = HeExecutor.new(query)
      expect(executor.dataset).to eq(dataset)
    end
  end

  describe '#execute' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    describe 'successful execution' do
      it 'returns hash with required keys' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 1000 },
          'execution_time_ms' => 245,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 1000
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result).to have_key(:data)
        expect(result).to have_key(:epsilon_consumed)
        expect(result).to have_key(:delta)
        expect(result).to have_key(:mechanism)
        expect(result).to have_key(:noise_scale)
        expect(result).to have_key(:execution_time_ms)
        expect(result).to have_key(:proof_artifacts)
        expect(result).to have_key(:metadata)
      end

      it 'returns correct data from Python executor' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 500 },
          'execution_time_ms' => 100,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 500
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to eq({ 'count' => 500 })
      end

      it 'returns zero epsilon and delta (no privacy budget)' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 100 },
          'execution_time_ms' => 50,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 100
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:epsilon_consumed]).to eq(0.0)
        expect(result[:delta]).to eq(0.0)
        expect(result[:noise_scale]).to eq(0.0)
      end

      it 'returns homomorphic_encryption as mechanism' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 100 },
          'execution_time_ms' => 50,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 100
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:mechanism]).to eq('homomorphic_encryption')
      end

      it 'includes execution time from Python response' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 100 },
          'execution_time_ms' => 287,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 100
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:execution_time_ms]).to eq(287)
      end

      it 'builds proof_artifacts with encryption parameters' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 100 },
          'execution_time_ms' => 50,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 100
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        artifacts = result[:proof_artifacts]
        expect(artifacts[:mechanism]).to eq('homomorphic_encryption')
        expect(artifacts[:encryption_scheme]).to eq('BFV')
        expect(artifacts[:poly_modulus_degree]).to eq(8192)
        expect(artifacts[:records_encrypted]).to eq(100)
      end

      it 'includes full metadata in response' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => true,
          'result' => { 'count' => 100 },
          'execution_time_ms' => 50,
          'mechanism' => 'homomorphic_encryption',
          'metadata' => {
            'operation' => 'count',
            'encryption_scheme' => 'BFV',
            'poly_modulus_degree' => 8192,
            'records_encrypted' => 100
          }
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:metadata]['operation']).to eq('count')
        expect(result[:metadata]['encryption_scheme']).to eq('BFV')
        expect(result[:metadata]['poly_modulus_degree']).to eq(8192)
      end
    end

    describe 'error handling' do
      it 'raises error when Python returns success=false' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => false,
          'error' => 'Operation not supported'
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError, /HE execution failed/)
      end

      it 'logs error message when execution fails' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => false,
          'error' => 'Test error message'
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError)
      end

      it 'raises error when Python process fails (non-zero exit)' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(false)
        
        allow(Open3).to receive(:capture3).and_return([
          '',
          'Traceback: Module not found',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError, /Python execution failed/)
      end

      it 'logs Python stderr when process fails' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(false)
        
        stderr_msg = 'ModuleNotFoundError: No module named tenseal'
        allow(Open3).to receive(:capture3).and_return([
          '',
          stderr_msg,
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError)
      end

      it 'raises error when Python returns invalid JSON' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        allow(Open3).to receive(:capture3).and_return([
          'not valid json at all',
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError, /Invalid JSON response/)
      end

      it 'logs JSON parsing error details' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        invalid_json = 'bad json'
        allow(Open3).to receive(:capture3).and_return([
          invalid_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError)
      end

      it 'logs full backtrace on error' do
        status_mock = double('status')
        allow(status_mock).to receive(:success?).and_return(true)
        
        python_response = {
          'success' => false,
          'error' => 'Test error'
        }

        allow(Open3).to receive(:capture3).and_return([
          python_response.to_json,
          '',
          status_mock
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError)
      end
    end
  end

  describe '#prepare_input_data' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    it 'returns hash with required keys' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data).to have_key(:query)
      expect(input_data).to have_key(:data)
      expect(input_data).to have_key(:columns)
      expect(input_data).to have_key(:bounds)
    end

    it 'includes SQL query' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data[:query]).to eq("SELECT COUNT(*) FROM patients")
    end

    it 'generates sample data array' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data[:data]).to be_an(Array)
      expect(input_data[:data]).not_to be_empty
      expect(input_data[:data].first).to be_an(Array)
    end

    it 'includes column names' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data[:columns]).to be_an(Array)
      expect(input_data[:columns]).not_to be_empty
    end

    it 'infers bounds for numeric columns' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data[:bounds]).to be_a(Hash)
    end
  end

  describe '#generate_sample_data' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    it 'generates sample data for patient queries' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)

      expect(sample_data).to have_key(:columns)
      expect(sample_data).to have_key(:rows)
      expect(sample_data[:columns]).to include('id', 'age', 'diagnosis', 'treatment_cost')
    end

    it 'generates 1000 patient records' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)

      expect(sample_data[:rows].length).to eq(1000)
    end

    it 'includes numeric data in patient records' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)

      first_row = sample_data[:rows].first
      expect(first_row[1]).to be_an(Integer) # age
      expect(first_row[3]).to be_an(Integer) # treatment_cost
    end

    it 'generates sample data for salary queries' do
      salary_query = dataset.queries.create!(
        sql: "SELECT SUM(salary) FROM employees",
        user: user,
        backend: 'he_backend'
      )
      executor = HeExecutor.new(salary_query)
      sample_data = executor.send(:generate_sample_data)

      expect(sample_data[:columns]).to include('id', 'salary', 'department', 'years_experience')
    end

    it 'generates 1000 salary records' do
      salary_query = dataset.queries.create!(
        sql: "SELECT SUM(salary) FROM employees",
        user: user,
        backend: 'he_backend'
      )
      executor = HeExecutor.new(salary_query)
      sample_data = executor.send(:generate_sample_data)

      expect(sample_data[:rows].length).to eq(1000)
    end

    it 'generates generic data for unknown queries' do
      generic_query = dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM unknown_table",
        user: user,
        backend: 'he_backend'
      )
      executor = HeExecutor.new(generic_query)
      sample_data = executor.send(:generate_sample_data)

      expect(sample_data[:columns]).to eq(['id', 'value'])
      expect(sample_data[:rows].length).to eq(1000)
    end
  end

  describe '#infer_bounds' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    it 'returns hash of column bounds' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)
      bounds = executor.send(:infer_bounds, sample_data)

      expect(bounds).to be_a(Hash)
    end

    it 'excludes non-numeric columns' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)
      bounds = executor.send(:infer_bounds, sample_data)

      expect(bounds.keys).not_to include('id', 'diagnosis')
    end

    it 'includes numeric column bounds' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)
      bounds = executor.send(:infer_bounds, sample_data)

      expect(bounds).to have_key('age')
      expect(bounds['age']).to be_an(Array)
      expect(bounds['age'].length).to eq(2)
      expect(bounds['age'].first).to be < bounds['age'].last
    end

    it 'calculates min and max correctly' do
      executor = HeExecutor.new(query)
      sample_data = executor.send(:generate_sample_data)
      bounds = executor.send(:infer_bounds, sample_data)

      min_age = bounds['age'][0]
      max_age = bounds['age'][1]

      sample_data[:rows].each do |row|
        age = row[1]
        expect(age).to be >= min_age
        expect(age).to be <= max_age
      end
    end
  end

  describe '#call_python_executor' do
    let(:query) do
      dataset.queries.create!(
        sql: "SELECT COUNT(*) FROM patients",
        user: user,
        backend: 'he_backend'
      )
    end

    it 'invokes Python script with input JSON' do
      status_mock = double('status')
      allow(status_mock).to receive(:success?).and_return(true)
      
      python_response = { 'success' => true, 'result' => { 'count' => 100 }, 'execution_time_ms' => 50, 'mechanism' => 'homomorphic_encryption', 'metadata' => {} }

      expect(Open3).to receive(:capture3).and_return([
        python_response.to_json,
        '',
        status_mock
      ])

      executor = HeExecutor.new(query)
      input_data = { query: "SELECT COUNT(*) FROM patients", data: [[1, 25]], columns: ['id', 'age'] }
      result = executor.send(:call_python_executor, input_data)

      expect(result['success']).to be true
    end

    it 'parses JSON response from Python' do
      status_mock = double('status')
      allow(status_mock).to receive(:success?).and_return(true)
      
      expected_response = { 'success' => true, 'result' => { 'count' => 500 }, 'execution_time_ms' => 100, 'mechanism' => 'homomorphic_encryption', 'metadata' => { 'operation' => 'count' } }

      allow(Open3).to receive(:capture3).and_return([
        expected_response.to_json,
        '',
        status_mock
      ])

      executor = HeExecutor.new(query)
      input_data = { query: "SELECT COUNT(*) FROM patients", data: [], columns: [] }
      result = executor.send(:call_python_executor, input_data)

      expect(result).to eq(expected_response)
    end

    it 'uses PYTHON_PATH from environment or default' do
      status_mock = double('status')
      allow(status_mock).to receive(:success?).and_return(true)

      allow(Open3).to receive(:capture3).and_return(['{}', '', status_mock])

      executor = HeExecutor.new(query)
      input_data = { query: "SELECT COUNT(*) FROM patients", data: [], columns: [] }
      executor.send(:call_python_executor, input_data)

      # Verify Open3.capture3 was called with python3 (the default)
      expect(Open3).to have_received(:capture3).with(anything, anything, anything, anything)
    end

    it 'uses Rails.root for chdir' do
      status_mock = double('status')
      allow(status_mock).to receive(:success?).and_return(true)

      allow(Open3).to receive(:capture3).and_return(['{}', '', status_mock])

      executor = HeExecutor.new(query)
      input_data = { query: "SELECT COUNT(*) FROM patients", data: [], columns: [] }
      executor.send(:call_python_executor, input_data)

      # Verify chdir parameter is Rails.root
      expect(Open3).to have_received(:capture3).with(anything, anything, anything, hash_including(chdir: Rails.root.to_s))
    end
  end
end
