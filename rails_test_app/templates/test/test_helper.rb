# typed: true

require "simplecov"
require "simplecov-json"
require "sorbet-runtime"

# Configure SimpleCov for Rails integration tests
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]

# Configure SimpleCov to focus on the logstruct gem code, not the Rails app itself
SimpleCov.start do
  T.bind(self, T.all(SimpleCov::Configuration, Kernel))

  # Only track files from the logstruct gem, not the Rails app
  # Get absolute path to logstruct lib directory
  logstruct_lib_dir = File.expand_path("../../../lib", __dir__)
  puts "Tracking files in: #{logstruct_lib_dir}"

  # Use absolute paths for tracking
  track_files "#{logstruct_lib_dir}/**/*.rb"

  # Exclude Rails app files
  add_filter "/app/"
  add_filter "/bin/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/test/"
  add_filter "/.bundle/"

  # Store in a separate directory for merging later
  coverage_dir "../../coverage_rails"
  command_name "Rails Integration Tests"

  # Enable branch coverage
  enable_coverage :branch
end

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
