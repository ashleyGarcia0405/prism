# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackendRegistry do
  describe ".available_backends" do
    it "returns list of available backends" do
      backends = BackendRegistry.available_backends
      expect(backends).to include("dp_sandbox", "mpc_backend", "he_backend")
      expect(backends).not_to include("enclave_backend")
    end
  end

  describe ".get_backend" do
    it "returns backend configuration" do
      config = BackendRegistry.get_backend("dp_sandbox")
      expect(config[:name]).to eq("Differential Privacy")
      expect(config[:available]).to be true
    end

    it "raises error for unknown backend" do
      expect { BackendRegistry.get_backend("unknown") }.to raise_error(BackendRegistry::BackendNotFoundError)
    end
  end

  describe ".backend_available?" do
    it "returns true for available backend" do
      expect(BackendRegistry.backend_available?("dp_sandbox")).to be true
    end

    it "returns false for unavailable backend" do
      expect(BackendRegistry.backend_available?("enclave_backend")).to be false
    end

    it "returns false for unknown backend" do
      expect(BackendRegistry.backend_available?("unknown")).to be false
    end
  end

  describe ".get_executor" do
    let(:query) { create(:query) }

    it "returns executor instance for available backend" do
      executor = BackendRegistry.get_executor("dp_sandbox", query)
      expect(executor).to be_a(DpSandbox)
    end

    it "raises error for unavailable backend" do
      expect do
        BackendRegistry.get_executor("enclave_backend", query)
      end.to raise_error(BackendRegistry::BackendNotAvailableError, /not available/)
    end

    it "includes alternatives in error message for unavailable backend" do
      expect do
        BackendRegistry.get_executor("enclave_backend", query)
      end.to raise_error(BackendRegistry::BackendNotAvailableError, /dp_sandbox/)
    end
  end

  describe ".supports_operation?" do
    it "returns true for supported operation" do
      expect(BackendRegistry.supports_operation?("dp_sandbox", "COUNT")).to be true
      expect(BackendRegistry.supports_operation?("mpc_backend", "SUM")).to be true
    end

    it "returns false for unsupported operation" do
      expect(BackendRegistry.supports_operation?("he_backend", "MIN")).to be false
      expect(BackendRegistry.supports_operation?("mpc_backend", "JOIN")).to be false
    end
  end

  describe ".all_backends" do
    it "returns metadata for all backends" do
      backends = BackendRegistry.all_backends
      expect(backends.keys).to include("dp_sandbox", "mpc_backend", "he_backend", "enclave_backend")
      expect(backends["dp_sandbox"][:name]).to eq("Differential Privacy")
      expect(backends["dp_sandbox"]).to have_key(:features)
    end
  end

  describe ".backend_parameters" do
    it "returns parameters for backend" do
      params = BackendRegistry.backend_parameters("dp_sandbox")
      expect(params).to have_key(:epsilon)
      expect(params[:epsilon][:required]).to be true
    end
  end
end
