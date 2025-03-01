# frozen_string_literal: true

require "rails_structured_logging"
require "sorbet-runtime"
require "json"

# Set up a minimal Rails environment for testing
require "rails"
require "active_support/all"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset RailsStructuredLogging configuration before each test
  config.before do
    RailsStructuredLogging.configuration = RailsStructuredLogging::Configuration.new
  end
end
