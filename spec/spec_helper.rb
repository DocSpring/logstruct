# typed: true
# frozen_string_literal: true

require "rspec"
require "rspec/sorbet/types"

require "json"
require "ostruct"
require "debug"

# Set up a minimal Rails environment for testing
require "rails"
require "active_support/all"

require "logstruct"

# Require support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset LogStruct configuration before each test
  config.before do
    T.bind(self, RSpec::Core::ExampleGroup)
    LogStruct.configuration = Configuration.new

    # Mock Rails.logger
    logger_double = double("Logger")
    allow(logger_double).to receive(:info)
    allow(logger_double).to receive(:error)
    allow(logger_double).to receive(:warn)
    allow(logger_double).to receive(:debug)
    allow(Rails).to receive(:logger).and_return(logger_double)
  end
end
