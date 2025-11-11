# This file is copied to spec/ when you run 'rails generate rspec:install'
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    command_name 'RSpec'
    merge_timeout 3600

    add_filter '/spec/'
    add_filter '/features/'
    add_filter '/config/'
    add_filter '/db/'

    add_group 'Controllers', 'app/controllers'
    add_group 'Models',      'app/models'
    add_group 'Services',    'app/services'
    add_group 'Jobs',        'app/jobs'
  end
end

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# Configure MPC keys for testing (must be set BEFORE Rails loads)
ENV['MPC_COORDINATOR_PRIVATE_KEY'] = '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAuQ32TDlQFAj6qe9ZL2U2Meoxadp/KnuT0RIy2agm27APkGaf\nshDqfYGX2AIhwD5ADLZ+qgkw+bFNGfqrk/8bxnzDPkxZHaeKtqBoAYH8ET0Rmont\nMylWUiBNzR0VJ0qdnbQTrHNafxv7ImBsSnO/Uafot4VHDfgpKb40hu6qvtuDmC57\nfGVqbg02RGvHgBsmwLIsJ0JN13kzcg3cg1xzyDNTTU2cg3k4BsXvsLBSH69lBQEV\nR8N13216mpj5HKa/NYgfHLTI62d1Y1f3zExTr63qfVqx+Hjtp8aWLxBZrgoxLvOp\nXmWGvyBnVO1PiYxVwLdHmGf6DwZuBnLjANUB3QIDAQABAoIBAErlF7WpzHsPV0PH\nlvTTpad1/SG2SJlNAnovP11P7Mok62ep4SAUMJMzC91kn3xKtWlvwrvWlHe6BlZp\nWV/Ac+FVRT/FbpvN3xoiuXVCwl3HtYQyJkn6hPEgGdzV1GXekQPuibfVx96B2JYF\nKE7JobjOmCUOT7+bnC1EycWCeqBbTnzieZ9NFTrKsl4FNWpoFaT4vVL7vy1wf48A\n1GwBgUoKqW6niUCWpDuem1IPvrBJ1xa40jorLKHQHD6y/RqdrADGxV1Gs6ViI3j1\n5SCD9px+754RVEzOAjaQg+xRyBicuXNcsaAkMXDr4RNR3fxsDZ03Un6RAd3ofZq4\npoccIBECgYEA7b8WsZUv4rDE/smpLcAR0sHqC72LeE5TvP7sv+jAoyJNlwLFC8A/\n83X4xgbxB4janj0wM6JBfPjKr8sGCjgHqSvWN7B4KvKoniC3vUxf0ZRrskIwMAzg\n0X63j/Jyvafs+fBXbr0VoneJcZCiabL01pH2KhGQj6p/07wUjty0l6cCgYEAx0M2\niK331PQkiHgZs9Aytr2XRGWcj5G4WdjalUepxzGdbjdMTTMvB3ffbxI5vnxXivk7\nslMbmWrbLTEZ+xPFlxNvhMhZ8vuCBvyUlnnQQbTSEQkpU5JkCgxi5HKv3clNB4ar\nAXwAJ2faHbt2PYe8z0dqNv0jAMaQTDJzAn2XStsCgYBerp9nEbcEXMnXfpB1u+xd\nNwTysAX/X5JRzmSS+SrezSaBYYT/7QyK9QyiMNmE2qfWJSAxMAlMr/hokj5Ri4bh\nhKfHfewdjo5Ai18hcG0olidd0qZGPJq8U+7e0PuJNHtX/rOTUpJvJZQDOkq0NaT0\nXyTeFCiyToCh3mGBk7wIOQKBgG8YZ0A/Fk0RrYi0xUe+jXfbLopAyNA243ycbgoK\nwXrAi9CWXiEwp0jXqagoli9A7iIaoRDkSx/3Nqn0lVKqDGEVwfhbJ+NUHIO+sS1Q\nTy9DHFfJLtRcaxA7JavO0YSrJhpLF+6k7wUJXs9y5BKcKkW6wFpWOfzFuE/zVLIP\nyZk/AoGBAOSK7mZEPFpE4UGbTBdB1oENIeNAZMdYEUM96siygWWRArwqvpqqbi8A\nrcIUHFOAAJSm2xjgFdulz73DACwsNHNDaNOFnZNruDNBD+6trvfBJvFOv1gLKVrj\nih2uc+I8LTY2rMxr40Skz6+LTIz4d2g7BZ6qHRY7Ag3xydDe2l5T\n-----END RSA PRIVATE KEY-----\n'
ENV['MPC_COORDINATOR_PUBLIC_KEY'] = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuQ32TDlQFAj6qe9ZL2U2\nMeoxadp/KnuT0RIy2agm27APkGafshDqfYGX2AIhwD5ADLZ+qgkw+bFNGfqrk/8b\nxnzDPkxZHaeKtqBoAYH8ET0RmontMylWUiBNzR0VJ0qdnbQTrHNafxv7ImBsSnO/\nUafot4VHDfgpKb40hu6qvtuDmC57fGVqbg02RGvHgBsmwLIsJ0JN13kzcg3cg1xz\nyDNTTU2cg3k4BsXvsLBSH69lBQEVR8N13216mpj5HKa/NYgfHLTI62d1Y1f3zExT\nr63qfVqx+Hjtp8aWLxBZrgoxLvOpXmWGvyBnVO1PiYxVwLdHmGf6DwZuBnLjANUB\n3QIDAQAB\n-----END PUBLIC KEY-----\n'

# Load files in spec/support

require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
# Configure MPC keys for testing
ENV['MPC_COORDINATOR_PRIVATE_KEY'] = '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAuQ32TDlQFAj6qe9ZL2U2Meoxadp/KnuT0RIy2agm27APkGaf\nshDqfYGX2AIhwD5ADLZ+qgkw+bFNGfqrk/8bxnzDPkxZHaeKtqBoAYH8ET0Rmont\nMylWUiBNzR0VJ0qdnbQTrHNafxv7ImBsSnO/Uafot4VHDfgpKb40hu6qvtuDmC57\nfGVqbg02RGvHgBsmwLIsJ0JN13kzcg3cg1xzyDNTTU2cg3k4BsXvsLBSH69lBQEV\nR8N13216mpj5HKa/NYgfHLTI62d1Y1f3zExTr63qfVqx+Hjtp8aWLxBZrgoxLvOp\nXmWGvyBnVO1PiYxVwLdHmGf6DwZuBnLjANUB3QIDAQABAoIBAErlF7WpzHsPV0PH\nlvTTpad1/SG2SJlNAnovP11P7Mok62ep4SAUMJMzC91kn3xKtWlvwrvWlHe6BlZp\nWV/Ac+FVRT/FbpvN3xoiuXVCwl3HtYQyJkn6hPEgGdzV1GXekQPuibfVx96B2JYF\nKE7JobjOmCUOT7+bnC1EycWCeqBbTnzieZ9NFTrKsl4FNWpoFaT4vVL7vy1wf48A\n1GwBgUoKqW6niUCWpDuem1IPvrBJ1xa40jorLKHQHD6y/RqdrADGxV1Gs6ViI3j1\n5SCD9px+754RVEzOAjaQg+xRyBicuXNcsaAkMXDr4RNR3fxsDZ03Un6RAd3ofZq4\npoccIBECgYEA7b8WsZUv4rDE/smpLcAR0sHqC72LeE5TvP7sv+jAoyJNlwLFC8A/\n83X4xgbxB4janj0wM6JBfPjKr8sGCjgHqSvWN7B4KvKoniC3vUxf0ZRrskIwMAzg\n0X63j/Jyvafs+fBXbr0VoneJcZCiabL01pH2KhGQj6p/07wUjty0l6cCgYEAx0M2\niK331PQkiHgZs9Aytr2XRGWcj5G4WdjalUepxzGdbjdMTTMvB3ffbxI5vnxXivk7\nslMbmWrbLTEZ+xPFlxNvhMhZ8vuCBvyUlnnQQbTSEQkpU5JkCgxi5HKv3clNB4ar\nAXwAJ2faHbt2PYe8z0dqNv0jAMaQTDJzAn2XStsCgYBerp9nEbcEXMnXfpB1u+xd\nNwTysAX/X5JRzmSS+SrezSaBYYT/7QyK9QyiMNmE2qfWJSAxMAlMr/hokj5Ri4bh\nhKfHfewdjo5Ai18hcG0olidd0qZGPJq8U+7e0PuJNHtX/rOTUpJvJZQDOkq0NaT0\nXyTeFCiyToCh3mGBk7wIOQKBgG8YZ0A/Fk0RrYi0xUe+jXfbLopAyNA243ycbgoK\nwXrAi9CWXiEwp0jXqagoli9A7iIaoRDkSx/3Nqn0lVKqDGEVwfhbJ+NUHIO+sS1Q\nTy9DHFfJLtRcaxA7JavO0YSrJhpLF+6k7wUJXs9y5BKcKkW6wFpWOfzFuE/zVLIP\nyZk/AoGBAOSK7mZEPFpE4UGbTBdB1oENIeNAZMdYEUM96siygWWRArwqvpqqbi8A\nrcIUHFOAAJSm2xjgFdulz73DACwsNHNDaNOFnZNruDNBD+6trvfBJvFOv1gLKVrj\nih2uc+I8LTY2rMxr40Skz6+LTIz4d2g7BZ6qHRY7Ag3xydDe2l5T\n-----END RSA PRIVATE KEY-----\n'
ENV['MPC_COORDINATOR_PUBLIC_KEY'] = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuQ32TDlQFAj6qe9ZL2U2\nMeoxadp/KnuT0RIy2agm27APkGafshDqfYGX2AIhwD5ADLZ+qgkw+bFNGfqrk/8b\nxnzDPkxZHaeKtqBoAYH8ET0RmontMylWUiBNzR0VJ0qdnbQTrHNafxv7ImBsSnO/\nUafot4VHDfgpKb40hu6qvtuDmC57fGVqbg02RGvHgBsmwLIsJ0JN13kzcg3cg1xz\nyDNTTU2cg3k4BsXvsLBSH69lBQEVR8N13216mpj5HKa/NYgfHLTI62d1Y1f3zExT\nr63qfVqx+Hjtp8aWLxBZrgoxLvOpXmWGvyBnVO1PiYxVwLdHmGf6DwZuBnLjANUB\n3QIDAQAB\n-----END PUBLIC KEY-----\n'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
