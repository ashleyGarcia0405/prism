# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/mpc_engine'

RSpec.describe MPCEngine do
  describe '.generate_shares' do
    it 'generates shares that sum to original value' do
      value = 100
      num_parties = 3

      shares = MPCEngine.generate_shares(value, num_parties)

      expect(shares.length).to eq(num_parties)
      expect(shares.sum).to be_within(0.0001).of(value)
    end

    it 'generates correct number of shares' do
      shares = MPCEngine.generate_shares(50, 5)
      expect(shares.length).to eq(5)
    end

    it 'works with negative values' do
      shares = MPCEngine.generate_shares(-25, 3)
      expect(shares.sum).to be_within(0.0001).of(-25)
    end

    it 'works with decimal values' do
      shares = MPCEngine.generate_shares(123.456, 4)
      expect(shares.sum).to be_within(0.0001).of(123.456)
    end

    it 'raises error if num_parties less than 2' do
      expect {
        MPCEngine.generate_shares(100, 1)
      }.to raise_error(ArgumentError, "num_parties must be at least 2")
    end

    it 'raises error if value is not numeric' do
      expect {
        MPCEngine.generate_shares("not a number", 3)
      }.to raise_error(ArgumentError, "value must be numeric")
    end

    it 'generates different shares each time (randomness)' do
      shares1 = MPCEngine.generate_shares(100, 3)
      shares2 = MPCEngine.generate_shares(100, 3)

      # Shares should be different due to randomness
      expect(shares1).not_to eq(shares2)
    end
  end

  describe '.reconstruct' do
    it 'reconstructs original value from shares' do
      original = 100
      shares = MPCEngine.generate_shares(original, 3)

      reconstructed = MPCEngine.reconstruct(shares)

      expect(reconstructed).to be_within(0.0001).of(original)
    end

    it 'works with manually created shares' do
      shares = [45.5, 30.2, 24.3]
      result = MPCEngine.reconstruct(shares)

      expect(result).to be_within(0.0001).of(100.0)
    end

    it 'works with negative shares' do
      shares = [150, -30, -20]
      result = MPCEngine.reconstruct(shares)

      expect(result).to eq(100)
    end

    it 'raises error if shares is not an array' do
      expect {
        MPCEngine.reconstruct("not an array")
      }.to raise_error(ArgumentError, "shares must be an array")
    end

    it 'raises error if shares is empty' do
      expect {
        MPCEngine.reconstruct([])
      }.to raise_error(ArgumentError, "shares cannot be empty")
    end
  end

  describe '.add_noise' do
    it 'adds noise to value' do
      value = 100.0
      noisy_value = MPCEngine.add_noise(value, epsilon: 0.1)

      # Noisy value should be different from original
      expect(noisy_value).not_to eq(value)
    end

    it 'noise magnitude decreases with larger epsilon' do
      value = 100.0
      samples_small_epsilon = 100.times.map { MPCEngine.add_noise(value, epsilon: 0.01) }
      samples_large_epsilon = 100.times.map { MPCEngine.add_noise(value, epsilon: 1.0) }

      # Smaller epsilon = more noise = larger variance
      variance_small = samples_small_epsilon.map { |v| (v - value)**2 }.sum / samples_small_epsilon.size
      variance_large = samples_large_epsilon.map { |v| (v - value)**2 }.sum / samples_large_epsilon.size

      expect(variance_small).to be > variance_large
    end

    it 'accepts custom sensitivity parameter' do
      value = 100.0
      noisy_value = MPCEngine.add_noise(value, sensitivity: 2.0, epsilon: 0.1)

      expect(noisy_value).not_to eq(value)
    end

    it 'raises error if epsilon is not positive' do
      expect {
        MPCEngine.add_noise(100, epsilon: 0)
      }.to raise_error(ArgumentError, "epsilon must be positive")

      expect {
        MPCEngine.add_noise(100, epsilon: -0.5)
      }.to raise_error(ArgumentError, "epsilon must be positive")
    end

    it 'raises error if sensitivity is not positive' do
      expect {
        MPCEngine.add_noise(100, sensitivity: 0, epsilon: 0.1)
      }.to raise_error(ArgumentError, "sensitivity must be positive")
    end
  end

  describe '.generate_masking_noise' do
    it 'generates random noise' do
      noise1 = MPCEngine.generate_masking_noise
      noise2 = MPCEngine.generate_masking_noise

      # Should generate different noise each time
      expect(noise1).not_to eq(noise2)
    end

    it 'generates noise within specified magnitude' do
      magnitude = 100
      noise_samples = 100.times.map { MPCEngine.generate_masking_noise(magnitude: magnitude) }

      # All noise should be within [-magnitude, magnitude]
      noise_samples.each do |noise|
        expect(noise).to be >= -magnitude
        expect(noise).to be <= magnitude
      end
    end

    it 'accepts custom magnitude parameter' do
      noise = MPCEngine.generate_masking_noise(magnitude: 50)

      expect(noise).to be >= -50
      expect(noise).to be <= 50
    end

    it 'noise distribution is roughly centered around zero' do
      samples = 1000.times.map { MPCEngine.generate_masking_noise(magnitude: 1000) }
      mean = samples.sum / samples.size

      # Mean should be close to zero (within 10% of magnitude)
      expect(mean.abs).to be < 100
    end
  end

  describe 'end-to-end MPC simulation' do
    it 'simulates 3-party SUM computation' do
      # Three parties have local values
      org_a_value = 100
      org_b_value = 200
      org_c_value = 300
      true_sum = 600

      # Each party generates masking noise
      noise_a = MPCEngine.generate_masking_noise(magnitude: 1000)
      noise_b = MPCEngine.generate_masking_noise(magnitude: 1000)
      noise_c = MPCEngine.generate_masking_noise(magnitude: 1000)

      # Each party adds noise to their value (creates share)
      share_a = org_a_value + noise_a
      share_b = org_b_value + noise_b
      share_c = org_c_value + noise_c

      # Coordinator sums all shares
      noisy_sum = share_a + share_b + share_c

      # Coordinator subtracts total noise to get true sum
      total_noise = noise_a + noise_b + noise_c
      reconstructed_sum = noisy_sum - total_noise

      # Result should match true sum
      expect(reconstructed_sum).to be_within(0.0001).of(true_sum)
    end

    it 'adds differential privacy noise to final result' do
      true_value = 1000.0

      # Add DP noise
      dp_value = MPCEngine.add_noise(true_value, epsilon: 0.1)

      # DP value should be close to true value but not exact
      expect((dp_value - true_value).abs).to be > 0
      expect((dp_value - true_value).abs).to be < 500 # Reasonable noise level
    end
  end
end