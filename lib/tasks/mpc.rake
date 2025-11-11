# frozen_string_literal: true

namespace :mpc do
  desc "Generate RSA key pair for MPC coordinator"
  task generate_keys: :environment do
    puts "Generating RSA key pair for MPC coordinator..."
    puts "=" * 80

    keys = MPCKeys.generate_key_pair(2048)

    puts "\nPRIVATE KEY (Keep secure! Do NOT commit to git!):"
    puts "=" * 80
    puts keys[:private_key]
    puts "=" * 80

    puts "\nPUBLIC KEY (Can be shared with participants):"
    puts "=" * 80
    puts keys[:public_key]
    puts "=" * 80

    puts "\nAdd these to your environment:"
    puts "=" * 80
    puts "export MPC_COORDINATOR_PRIVATE_KEY='#{keys[:private_key].gsub("\n", '\\n')}'"
    puts "export MPC_COORDINATOR_PUBLIC_KEY='#{keys[:public_key].gsub("\n", '\\n')}'"
    puts "=" * 80

    puts "\nOr add to Rails credentials:"
    puts "rails credentials:edit"
    puts "\nAdd under 'mpc' section:"
    puts "mpc:"
    puts "  coordinator_private_key: |"
    keys[:private_key].each_line { |line| puts "    #{line}" }
    puts "  coordinator_public_key: |"
    keys[:public_key].each_line { |line| puts "    #{line}" }

    puts "\nKey generation complete!"
  end

  desc "Verify MPC keys are configured"
  task verify_keys: :environment do
    puts "Verifying MPC coordinator keys..."

    if MPCKeys.keys_configured?
      puts "Both private and public keys are configured!"

      # Test encryption/decryption
      test_message = "Hello MPC!"
      encrypted = MPCKeys.coordinator_public_key.public_encrypt(test_message)
      decrypted = MPCKeys.coordinator_private_key.private_decrypt(encrypted)

      if decrypted == test_message
        puts "Keys work correctly (encryption/decryption test passed)"
      else
        puts "Keys don't work correctly (decryption failed)"
      end
    else
      puts "Keys are not configured"
      puts "Run: rake mpc:generate_keys"
    end
  end
end