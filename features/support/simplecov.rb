require 'simplecov'
SimpleCov.command_name 'Cucumber'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
  add_filter '/features/'
end
