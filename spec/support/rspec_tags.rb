# frozen_string_literal: true

# Tag filters for optional test requirements
#
# Usage:
#   Run all tests except those requiring TenSEAL:
#     bundle exec rspec --tag ~requires_tenseal
#
#   Run all tests except those requiring SGX hardware:
#     bundle exec rspec --tag ~requires_sgx_hardware
#
#   Run all tests except both:
#     bundle exec rspec --tag ~requires_tenseal --tag ~requires_sgx_hardware
#
# Or configure in .rspec to skip by default

RSpec.configure do |config|
  # Uncomment to skip TenSEAL tests by default
  # config.filter_run_excluding requires_tenseal: true

  # Uncomment to skip SGX tests by default
  # config.filter_run_excluding requires_sgx_hardware: true
end
