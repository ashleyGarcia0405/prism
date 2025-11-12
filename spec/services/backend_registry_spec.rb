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

    it "raises error for unknown backend" do
      expect {
        BackendRegistry.backend_parameters("unknown")
      }.to raise_error(BackendRegistry::BackendNotFoundError)
    end

    it "returns empty hash for backend without parameters" do
      params = BackendRegistry.backend_parameters("enclave_backend")
      expect(params).to eq({})
    end
  end

  describe "unhappy paths" do
    context "with nil backend_key" do
      it "returns false for backend_available?" do
        expect(BackendRegistry.backend_available?(nil)).to be false
      end

      it "raises error for get_backend" do
        expect {
          BackendRegistry.get_backend(nil)
        }.to raise_error(BackendRegistry::BackendNotFoundError)
      end
    end

    context "with empty string backend_key" do
      it "returns false for backend_available?" do
        expect(BackendRegistry.backend_available?("")).to be false
      end

      it "raises error for get_backend" do
        expect {
          BackendRegistry.get_backend("")
        }.to raise_error(BackendRegistry::BackendNotFoundError)
      end
    end

    context "with case sensitivity" do
      it "is case-sensitive for backend keys" do
        expect(BackendRegistry.backend_available?("DP_SANDBOX")).to be false
        expect(BackendRegistry.backend_available?("Dp_Sandbox")).to be false
      end
    end

    context "with operation case handling" do
      it "handles lowercase operation names" do
        expect(BackendRegistry.supports_operation?("dp_sandbox", "count")).to be true
      end

      it "handles mixed case operation names" do
        expect(BackendRegistry.supports_operation?("dp_sandbox", "Count")).to be true
      end
    end

    context "when backend has no executor_class" do
      let(:query) { create(:query) }

      it "raises BackendNotAvailableError" do
        # enclave_backend is unavailable
        expect {
          BackendRegistry.get_executor("enclave_backend", query)
        }.to raise_error(BackendRegistry::BackendNotAvailableError)
      end
    end

    context "when backend has nil features" do
      it "handles missing features gracefully in supports_operation?" do
        allow(BackendRegistry).to receive(:get_backend).and_return({ features: nil })

        result = BackendRegistry.supports_operation?("test_backend", "COUNT")
        expect(result).to be false
      end
    end

    context "with backend alternatives" do
      it "includes alternatives in unavailable backend" do
        config = BackendRegistry.get_backend("enclave_backend")
        expect(config[:alternatives]).to include("dp_sandbox", "mpc_backend", "he_backend")
      end

      it "includes unavailable_reason for unavailable backend" do
        config = BackendRegistry.get_backend("enclave_backend")
        expect(config[:unavailable_reason]).to be_present
        expect(config[:unavailable_reason]).to include("Intel SGX")
      end
    end

    context "with mocked backends" do
      it "identifies mpc_backend as mocked" do
        config = BackendRegistry.get_backend("mpc_backend")
        expect(config[:mocked]).to be true
      end

      it "identifies dp_sandbox as not mocked" do
        config = BackendRegistry.get_backend("dp_sandbox")
        expect(config[:mocked]).to be false
      end

      it "identifies he_backend as not mocked" do
        config = BackendRegistry.get_backend("he_backend")
        expect(config[:mocked]).to be false
      end
    end

    context "with parameter defaults" do
      it "has default delta for dp_sandbox" do
        params = BackendRegistry.backend_parameters("dp_sandbox")
        expect(params[:delta][:default]).to eq(1e-5)
      end

      it "has default key_size for he_backend" do
        params = BackendRegistry.backend_parameters("he_backend")
        expect(params[:key_size][:default]).to eq(4096)
      end

      it "has no default for epsilon" do
        params = BackendRegistry.backend_parameters("dp_sandbox")
        expect(params[:epsilon]).not_to have_key(:default)
      end
    end

    context "with feature limitations" do
      it "he_backend does not support AVG" do
        expect(BackendRegistry.supports_operation?("he_backend", "AVG")).to be false
      end

      it "he_backend does not support MIN" do
        expect(BackendRegistry.supports_operation?("he_backend", "MIN")).to be false
      end

      it "he_backend does not support MAX" do
        expect(BackendRegistry.supports_operation?("he_backend", "MAX")).to be false
      end

      it "mpc_backend does not support MIN" do
        expect(BackendRegistry.supports_operation?("mpc_backend", "MIN")).to be false
      end

      it "mpc_backend does not support MAX" do
        expect(BackendRegistry.supports_operation?("mpc_backend", "MAX")).to be false
      end

      it "mpc_backend does not support JOIN" do
        expect(BackendRegistry.supports_operation?("mpc_backend", "JOIN")).to be false
      end
    end

    context "with all backends iteration" do
      it "includes both available and unavailable backends" do
        all = BackendRegistry.all_backends
        expect(all.keys).to include("dp_sandbox")
        expect(all.keys).to include("enclave_backend")
      end

      it "does not expose internal keys in all_backends" do
        all = BackendRegistry.all_backends
        all.each do |_, config|
          expect(config).not_to have_key(:executor_class)
          expect(config).not_to have_key(:parameters)
          expect(config).not_to have_key(:unavailable_reason)
          expect(config).not_to have_key(:alternatives)
        end
      end
    end
  end
end
