# typed: true

require "simplecov"
require "simplecov-json"
require "sorbet-runtime"
require "debug"

# Configure SimpleCov for Rails integration tests
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]

# We need to configure SimpleCov before loading any application code
SimpleCov.start do
  T.bind(self, T.all(SimpleCov::Configuration, Kernel))

  gem_path = File.expand_path("../../../../", __FILE__)
  SimpleCov.root(gem_path)

  add_filter "rails_test_app"

  # Coverage is stored in a directory relative to the Rails app
  coverage_dir "coverage_rails"
  # command_name "test:integration"

  # Enable branch coverage
  enable_coverage :branch
  primary_coverage :branch
end

# Require logstruct after starting SimpleCov
require "logstruct"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"

# Configure colorful test output
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Configure the test database
class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  # fixtures :all

  # Add more helper methods to be used by all tests here...

  # Helper method to run jobs synchronously
  def perform_enqueued_jobs
    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    jobs.each do |job|
      ActiveJob::Base.execute job
    end
  end
end

# Ensure LogStruct is enabled and emits JSON in tests across Rails versions
begin
  LogStruct.configure do |config|
    config.enabled = true
    # Prefer production-style JSON in development/test
    config.integrations.prefer_json_in_development = true
  end
rescue NameError
  # LogStruct not loaded; ignore
end
