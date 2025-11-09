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
  end
end
