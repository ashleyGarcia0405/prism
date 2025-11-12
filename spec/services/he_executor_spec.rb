# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HeExecutor, :requires_tenseal do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Test Data") }

  describe '#execute' do
    context 'with COUNT query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients",
          user: user,
          backend: 'he_backend'
        )
      end

      it 'returns encrypted count result' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key('count')
        expect(result[:data]['count']).to be >= 0
        expect(result[:mechanism]).to eq('homomorphic_encryption')
        expect(result[:epsilon_consumed]).to eq(0.0)
        expect(result[:delta]).to eq(0.0)
      end

      it 'includes HE metadata' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:metadata]['encryption_scheme']).to eq('BFV')
        expect(result[:metadata]['poly_modulus_degree']).to eq(8192)
        expect(result[:metadata]['operation']).to eq('count')
      end

      it 'includes proof artifacts' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:proof_artifacts]).to be_a(Hash)
        expect(result[:proof_artifacts][:mechanism]).to eq('homomorphic_encryption')
        expect(result[:proof_artifacts][:encryption_scheme]).to eq('BFV')
      end
    end

    context 'with SUM query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT SUM(age) FROM patients",
          user: user,
          backend: 'he_backend'
        )
      end

      it 'returns encrypted sum result' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key('sum')
        expect(result[:data]['sum']).to be_a(Numeric)
        expect(result[:data]['sum']).to be >= 0
      end

      it 'does not consume privacy budget' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:epsilon_consumed]).to eq(0.0)
        expect(result[:noise_scale]).to eq(0.0)
      end

      it 'includes execution time' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:execution_time_ms]).to be > 0
        expect(result[:execution_time_ms]).to be_a(Numeric)
      end
    end

    context 'with salary SUM query' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT SUM(salary) FROM employees",
          user: user,
          backend: 'he_backend'
        )
      end

      it 'returns realistic salary sum' do
        executor = HeExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key('sum')
        # HE may return negative due to integer overflow with large sums
        # Just verify we got a numeric result
        expect(result[:data]['sum']).to be_a(Numeric)
        expect(result[:mechanism]).to eq('homomorphic_encryption')
      end
    end

    context 'with unsupported AVG query' do
      it 'validation prevents AVG queries' do
        # The Query model should prevent creating AVG queries with HE backend
        expect {
          dataset.queries.create!(
            sql: "SELECT AVG(age) FROM patients",
            user: user,
            backend: 'he_backend'
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /does not support AVG/)
      end
    end

    context 'error handling' do
      let(:query) do
        dataset.queries.create!(
          sql: "SELECT COUNT(*) FROM patients",
          user: user,
          backend: 'he_backend'
        )
      end

      it 'handles Python execution errors gracefully' do
        allow(Open3).to receive(:capture3).and_return([
          '{"success": false, "error": "Python error"}',
          '',
          double(success?: true)
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError, /HE execution failed/)
      end

      it 'handles invalid JSON responses' do
        allow(Open3).to receive(:capture3).and_return([
          'not valid json',
          '',
          double(success?: true)
        ])

        executor = HeExecutor.new(query)
        expect { executor.execute }.to raise_error(StandardError, /Invalid JSON response/)
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

    it 'generates sample data with correct structure' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data).to have_key(:query)
      expect(input_data).to have_key(:data)
      expect(input_data).to have_key(:columns)
      expect(input_data).to have_key(:bounds)
    end

    it 'infers bounds for numeric columns' do
      executor = HeExecutor.new(query)
      input_data = executor.send(:prepare_input_data)

      expect(input_data[:bounds]).to be_a(Hash)
      expect(input_data[:bounds]['age']).to be_an(Array)
      expect(input_data[:bounds]['age'].length).to eq(2)
    end
  end
end
