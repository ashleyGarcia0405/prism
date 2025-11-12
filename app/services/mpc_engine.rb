# frozen_string_literal: true

# MPCEngine provides core multi-party computation primitives
# Uses additive secret sharing for secure aggregation
module MPCEngine
  class << self
    # Generate additive shares for a value
    # Split a value into N random shares that sum back to the original
    #
    # @param value [Numeric] The value to share
    # @param num_parties [Integer] Number of parties (shares to generate)
    # @return [Array<Numeric>] Array of shares that sum to the original value
    #
    # Example:
    #   shares = MPCEngine.generate_shares(100, 3)
    #   # => [45.2, -10.7, 65.5]  (sums to 100)
    def generate_shares(value, num_parties)
      raise ArgumentError, "num_parties must be at least 2" if num_parties < 2
      raise ArgumentError, "value must be numeric" unless value.is_a?(Numeric)

      # Generate N-1 random shares
      shares = (num_parties - 1).times.map do
        # Generate random number in range [-value, 2*value] for good distribution
        range = value.abs * 2
        (SecureRandom.random_number * range * 2) - range
      end

      # Last share ensures sum equals original value
      last_share = value - shares.sum
      shares << last_share

      shares
    end

    # Reconstruct original value from shares
    #
    # @param shares [Array<Numeric>] Array of shares
    # @return [Numeric] The reconstructed original value
    #
    # Example:
    #   MPCEngine.reconstruct([45.2, -10.7, 65.5])
    #   # => 100.0
    def reconstruct(shares)
      raise ArgumentError, "shares must be an array" unless shares.is_a?(Array)
      raise ArgumentError, "shares cannot be empty" if shares.empty?

      shares.sum
    end

    # Add Laplace noise for differential privacy
    #
    # @param value [Numeric] The value to add noise to
    # @param sensitivity [Numeric] Sensitivity of the query (default: 1.0)
    # @param epsilon [Numeric] Privacy parameter (smaller = more privacy)
    # @return [Numeric] Value with noise added
    def add_noise(value, sensitivity: 1.0, epsilon: 0.1)
      raise ArgumentError, "epsilon must be positive" unless epsilon > 0
      raise ArgumentError, "sensitivity must be positive" unless sensitivity > 0

      scale = sensitivity / epsilon
      noise = laplace_noise(scale)
      value + noise
    end

    # Generate cryptographically secure random noise for masking
    # This noise is used to hide local results before sending to coordinator
    #
    # @param magnitude [Numeric] Maximum magnitude of noise (default: 1000)
    # @return [Numeric] Random noise value
    def generate_masking_noise(magnitude: 1000)
      # Generate random noise in range [-magnitude, magnitude]
      (SecureRandom.random_number * magnitude * 2) - magnitude
    end

    private

    # Generate Laplace-distributed random noise
    # Used for differential privacy
    def laplace_noise(scale)
      # Generate uniform random number in [-0.5, 0.5]
      u = SecureRandom.random_number - 0.5

      # Transform to Laplace distribution
      # Laplace PDF: (1/2b) * exp(-|x|/b) where b = scale
      -scale * Math.log(1 - 2 * u.abs) * (u <=> 0)
    end
  end
end

# Compatibility alias for default inflection (MpcEngine)
MpcEngine = MPCEngine
