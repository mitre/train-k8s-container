# frozen_string_literal: true

# SimpleCov must be loaded before application code
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/test/'
end

require 'logger'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Suppress logger output during tests (keeps test output clean)
  # Tests can override by providing explicit logger
  config.before(:each) do
    @null_logger = Logger.new(IO::NULL)
    ENV['RSPEC_RUNNING'] = 'true'
  end

  config.after(:each) do
    ENV.delete('RSPEC_RUNNING')
  end
end
