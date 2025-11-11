# frozen_string_literal: true

# MPC Key Configuration
# Generate RSA key pair for coordinator if not exists

module MPCKeys
  class << self
    def generate_key_pair(bits = 2048)
      key = OpenSSL::PKey::RSA.new(bits)

      {
        private_key: key.to_pem,
        public_key: key.public_key.to_pem
      }
    end

    def coordinator_public_key
      if ENV['MPC_COORDINATOR_PUBLIC_KEY'].present?
        OpenSSL::PKey::RSA.new(ENV['MPC_COORDINATOR_PUBLIC_KEY'])
      elsif Rails.application.credentials.dig(:mpc, :coordinator_public_key).present?
        OpenSSL::PKey::RSA.new(Rails.application.credentials.dig(:mpc, :coordinator_public_key))
      else
        Rails.logger.warn("MPC coordinator public key not configured. MPC functionality will be limited.")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Failed to load MPC coordinator public key: #{e.message}")
      nil
    end

    def coordinator_private_key
      if ENV['MPC_COORDINATOR_PRIVATE_KEY'].present?
        OpenSSL::PKey::RSA.new(ENV['MPC_COORDINATOR_PRIVATE_KEY'])
      elsif Rails.application.credentials.dig(:mpc, :coordinator_private_key).present?
        OpenSSL::PKey::RSA.new(Rails.application.credentials.dig(:mpc, :coordinator_private_key))
      else
        Rails.logger.warn("MPC coordinator private key not configured. MPC functionality will be limited.")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Failed to load MPC coordinator private key: #{e.message}")
      nil
    end

    def keys_configured?
      coordinator_public_key.present? && coordinator_private_key.present?
    end
  end
end

# Validate keys on startup (only in production)
if Rails.env.production? && !MPCKeys.keys_configured?
  Rails.logger.warn("=" * 80)
  Rails.logger.warn("WARNING: MPC coordinator keys not configured!")
  Rails.logger.warn("MPC functionality will not work without keys.")
  Rails.logger.warn("Run: rake mpc:generate_keys to generate a key pair.")
  Rails.logger.warn("=" * 80)
end