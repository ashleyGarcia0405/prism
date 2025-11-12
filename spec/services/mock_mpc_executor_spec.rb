# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockMPCExecutor do
  let(:dataset) { create(:dataset) }
  let(:user) { create(:user) }

  describe "#execute" do
    it "returns a hash with data" do
      query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
      executor = MockMPCExecutor.new(query)
      result = executor.execute

      expect(result).to be_a(Hash)
      expect(result).to have_key(:data)
    end

    it "returns nil epsilon_consumed (MPC doesn't use epsilon)" do
      query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
      executor = MockMPCExecutor.new(query)
      result = executor.execute

      expect(result[:epsilon_consumed]).to be_nil
      expect(result[:delta]).to be_nil
    end

    it "returns secret_sharing mechanism" do
      query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
      executor = MockMPCExecutor.new(query)
      result = executor.execute

      expect(result[:mechanism]).to eq("secret_sharing")
    end

    it "includes proof artifacts with MPC details" do
      query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
      executor = MockMPCExecutor.new(query)
      result = executor.execute

      expect(result[:proof_artifacts]).to include(
        protocol: "shamirs_secret_sharing",
        num_parties: 3,
        threshold: 2,
        mocked: true
      )
    end

    it "includes mocked flag in metadata" do
      query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
      executor = MockMpcExecutor.new(query)
      result = executor.execute

      expect(result[:metadata][:mocked]).to be true
      expect(result[:metadata][:backend]).to eq("mpc_backend")
    end

    context "with COUNT query" do
      it "returns count result" do
        query = create(:query, sql: "SELECT COUNT(*) FROM data", dataset: dataset, user: user)
        executor = MockMPCExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key(:count)
        expect(result[:data][:count]).to be_a(Integer)
      end
    end

    context "with SUM query" do
      it "returns sum result" do
        query = create(:query, sql: "SELECT SUM(amount) FROM data", dataset: dataset, user: user)
        executor = MockMPCExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key(:sum)
        expect(result[:data][:sum]).to be_a(Float)
      end
    end

    context "with AVG query" do
      it "returns average result" do
        query = create(:query, sql: "SELECT AVG(amount) FROM data", dataset: dataset, user: user)
        executor = MockMPCExecutor.new(query)
        result = executor.execute

        expect(result[:data]).to have_key(:avg)
        expect(result[:data][:avg]).to be_a(Float)
      end
    end
  end
end
