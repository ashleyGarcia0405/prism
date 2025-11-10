# frozen_string_literal: true

# BackendRegistry manages available query execution backends
# Provides registry of supported backends and their metadata
class BackendRegistry
  class BackendNotFoundError < StandardError; end
  class BackendNotAvailableError < StandardError; end

  BACKENDS = {
    "dp_sandbox" => {
      name: "Differential Privacy",
      executor_class: "DpSandbox",
      available: true,
      mocked: false,
      description: "Privacy-preserving queries on single datasets using statistical noise",
      features: [ "COUNT", "SUM", "AVG", "MIN", "MAX" ],
      privacy_guarantee: "ε-differential privacy with δ",
      parameters: {
        epsilon: { type: "float", required: true, description: "Privacy budget" },
        delta: { type: "float", required: false, default: 1e-5, description: "Privacy parameter" }
      }
    },
    "mpc_backend" => {
      name: "Multi-Party Computation",
      executor_class: "MockMpcExecutor",
      available: true,
      mocked: true,
      description: "Collaborative queries across multiple organizations using secret sharing",
      features: [ "COUNT", "SUM", "AVG" ],
      privacy_guarantee: "Cryptographic security via secret sharing",
      parameters: {
        num_parties: { type: "integer", required: true, description: "Number of participating organizations" }
      }
    },
    "he_backend" => {
      name: "Homomorphic Encryption",
      executor_class: "HeExecutor",
      available: true,
      mocked: false,
      description: "Computation on encrypted data using homomorphic encryption",
      features: [ "COUNT", "SUM" ],
      privacy_guarantee: "Cryptographic security via homomorphic encryption",
      parameters: {
        key_size: { type: "integer", required: false, default: 4096, description: "Encryption key size in bits" }
      }
    },
    "enclave_backend" => {
      name: "Secure Enclave",
      executor_class: nil,
      available: false,
      mocked: false,
      description: "Hardware-based trusted execution environment (Intel SGX)",
      features: [ "COUNT", "SUM", "AVG", "MIN", "MAX", "JOIN" ],
      privacy_guarantee: "Hardware-based isolation and attestation",
      parameters: {},
      unavailable_reason: "Requires Intel SGX-enabled hardware and Gramine runtime",
      alternatives: [ "dp_sandbox", "mpc_backend", "he_backend" ]
    }
  }.freeze

  class << self
    # Get list of all available backends
    def available_backends
      BACKENDS.select { |_key, config| config[:available] }.keys
    end

    # Get backend configuration
    def get_backend(backend_key)
      config = BACKENDS[backend_key]
      raise BackendNotFoundError, "Backend '#{backend_key}' not found" unless config

      config
    end

    # Check if backend is available
    def backend_available?(backend_key)
      config = BACKENDS[backend_key]
      return false unless config

      config[:available]
    end

    # Get executor instance for backend
    def get_executor(backend_key, query)
      config = get_backend(backend_key)

      unless config[:available]
        alternatives = config[:alternatives]&.join(", ") || "dp_sandbox"
        reason = config[:unavailable_reason] || "Backend not available"

        raise BackendNotAvailableError,
              "Backend '#{backend_key}' (#{config[:name]}) is not available. " \
              "#{reason}. Available alternatives: #{alternatives}"
      end

      executor_class_name = config[:executor_class]
      raise BackendNotAvailableError, "No executor configured for #{backend_key}" unless executor_class_name

      executor_class = executor_class_name.constantize
      executor_class.new(query)
    end

    # Validate backend supports operation
    def supports_operation?(backend_key, operation)
      config = get_backend(backend_key)
      features = config[:features] || []
      features.include?(operation.to_s.upcase)
    end

    # Get all backends metadata
    def all_backends
      BACKENDS.transform_values do |config|
        config.slice(:name, :description, :available, :mocked, :features, :privacy_guarantee)
      end
    end

    # Get backend parameters definition
    def backend_parameters(backend_key)
      config = get_backend(backend_key)
      config[:parameters] || {}
    end
  end
end
