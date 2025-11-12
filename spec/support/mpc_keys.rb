# frozen_string_literal: true

# Configure MPC keys for testing
RSpec.configure do |config|
  config.before(:suite) do
    # Create temporary key files for testing
    private_key = OpenSSL::PKey::RSA.new(2048)
    public_key = private_key.public_key

    ENV['MPC_COORDINATOR_PRIVATE_KEY'] = private_key.to_pem
    ENV['MPC_COORDINATOR_PUBLIC_KEY'] = public_key.to_pem

    # Reload MPCKeys module to pick up new env variables
    load Rails.root.join('config/initializers/mpc_keys.rb')
  end
end
