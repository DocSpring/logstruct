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

  # Coverage is stored in a directory relative to the Rails app
  coverage_dir "../../coverage_rails"
  command_name "test:integration"

  # Enable branch coverage
  enable_coverage :branch
  primary_coverage :branch

  # The key issue: The path in the Rails test app needs to correctly point to the gem
  # when loaded as a path-based gem
  gem_path = File.expand_path("../../../../", __FILE__)
  lib_path = File.join(gem_path, "lib")
  # puts "LogStruct gem path: #{gem_path}"
  # puts "LogStruct lib path: #{lib_path}"
  add_group "LogStruct", lib_path

  # This will remove the :root_filter and :bundler_filter that come via simplecov's defaults
  filters.clear
  add_filter do |src|
    !(src.filename =~ /^#{lib_path}/)
  end

  track_files "#{lib_path}/**/*.rb"
end

debugger
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
