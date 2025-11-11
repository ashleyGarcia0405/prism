# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnclaveBackend do
  let(:organization) { Organization.create!(name: "Test Org") }
  let(:user) { organization.users.create!(name: "Test", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Test Data") }
  
  # Create a mock query object (bypass Query model validation since enclave_backend is unavailable)
  let(:mock_query) do
    query = double("Query")
    allow(query).to receive(:sql).and_return("SELECT COUNT(*) FROM patients")
    query
  end

  describe '#execute' do
    it 'raises NotImplementedError with detailed message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('Secure Enclave Backend - Not Yet Implemented')
        expect(error.message).to include('Intel SGX')
        expect(error.message).to include('Gramine')
        expect(error.message).to include('AVAILABLE ALTERNATIVES')
      end
    end

    it 'includes implementation phases in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('Phase 1')
        expect(error.message).to include('Phase 2')
        expect(error.message).to include('Phase 3')
      end
    end

    it 'lists alternative backends in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('DIFFERENTIAL PRIVACY')
        expect(error.message).to include('HOMOMORPHIC ENCRYPTION')
        expect(error.message).to include('MULTI-PARTY COMPUTATION')
      end
    end

    it 'includes hardware requirements in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('HARDWARE REQUIREMENTS')
        expect(error.message).to include('SGX support')
        expect(error.message).to include('EPC')
      end
    end

    it 'includes software stack requirements in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('SOFTWARE STACK')
        expect(error.message).to include('Gramine')
        expect(error.message).to include('Occlum')
        expect(error.message).to include('attestation')
      end
    end

    it 'includes security considerations in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('SECURITY CONSIDERATIONS')
        expect(error.message).to include('Side-channel')
        expect(error.message).to include('Spectre')
      end
    end

    it 'includes reference links in error message' do
      backend = EnclaveBackend.new(mock_query)

      expect { backend.execute }.to raise_error(EnclaveBackend::NotImplementedError) do |error|
        expect(error.message).to include('REFERENCES')
        expect(error.message).to include('intel.com')
        expect(error.message).to include('gramineproject.io')
      end
    end
  end

  describe '#initialize' do
    it 'accepts a query object' do
      backend = EnclaveBackend.new(mock_query)
      expect(backend.query).to eq(mock_query)
    end
  end

  describe 'integration with BackendRegistry' do
    it 'is registered as unavailable in BackendRegistry' do
      expect(BackendRegistry.backend_available?('enclave_backend')).to be false
    end

    it 'raises BackendNotAvailableError when getting executor' do
      expect {
        BackendRegistry.get_executor('enclave_backend', mock_query)
      }.to raise_error(BackendRegistry::BackendNotAvailableError, /not available/)
    end

    it 'lists alternatives in BackendRegistry' do
      config = BackendRegistry.get_backend('enclave_backend')
      expect(config[:alternatives]).to include('dp_sandbox', 'mpc_backend', 'he_backend')
    end
  end
end

