# typed: strict
# frozen_string_literal: true

# Start SimpleCov before requiring any other files
require "simplecov"
require "simplecov-json"
require "sorbet-runtime"

# Configure formatters before starting
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]

SimpleCov.start do
  T.bind(self, SimpleCov::Configuration)
  coverage_dir "./coverage"
  command_name "test"

  add_filter "test/"

  enable_coverage :branch
  primary_coverage :branch
end

require "minitest/autorun"
require "minitest/reporters"
require "climate_control"

# Use pretty reporters with minimal output
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new(color: true)

# Require standard libraries
require "json"
require "ostruct"
require "fileutils"

# Dev libraries
begin
  require "debug"
rescue LoadError
  # Debug not available (e.g. on CI)
end

# Ensure log directory exists
FileUtils.mkdir_p(File.expand_path("../log", __dir__))

# Set Rails environment to test
ENV["RAILS_ENV"] = "test"

# Require Rails
require "rails"
require "active_support/test_case"

# Require the gem BEFORE initializing Rails (like a real Rails app)
require "log_struct"

# Configure LogStruct
LogStruct.configure do |config|
  config.enabled = true

  # Configure integrations
  config.integrations.enable_lograge = true
  config.integrations.enable_actionmailer = true
  config.integrations.enable_activejob = true
  config.integrations.enable_sidekiq = true
  config.integrations.enable_shrine = true
  config.integrations.enable_activestorage = true
  config.integrations.enable_carrierwave = true
  config.integrations.enable_rack_error_handler = true
  config.integrations.enable_host_authorization = true

  # Configure filters
  config.filters.hash_salt = "test"
  config.filters.hash_length = 12
end

# Create a minimal Rails application for testing
class TestApp < Rails::Application
  extend T::Sig
  sig { returns(T::Boolean) }
  def self.eager_load_frameworks
    false
  end

  config.eager_load = false

  # Configure Rails filter_parameters
  config.filter_parameters = T.let(
    [:password, :token, :secret, :key, :access, :auth, :credentials],
    T::Array[Symbol]
  )

  # Fix Rails 8.1 deprecation warning for to_time timezone preservation
  config.active_support.to_time_preserves_timezone = :zone
end

# Initialize the application - Railtie initializers will run now
Rails.application.initialize!

# Override SemanticLogger appenders for testing - use StringIO to keep output clean
TEST_LOG_IO = StringIO.new
::SemanticLogger.clear_appenders!
::SemanticLogger.add_appender(
  io: TEST_LOG_IO,
  formatter: LogStruct::SemanticLogger::Formatter.new,
  async: false
)

# Clear the test log buffer before each test
class ActiveSupport::TestCase
  extend T::Sig

  setup do
    TEST_LOG_IO.truncate(0)
    TEST_LOG_IO.rewind
  end

  # Helper method for tests that need to capture and parse log output
  # Returns a StringIO that only contains logs from the test itself
  sig { returns(StringIO) }
  def setup_isolated_logger
    io = T.let(StringIO.new, StringIO)
    @saved_appenders = T.let(::SemanticLogger.appenders.dup, T.nilable(T::Array[T.untyped]))
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(
      io: io,
      formatter: LogStruct::SemanticLogger::Formatter.new,
      async: false
    )
    io
  end

  sig { void }
  def teardown_isolated_logger
    ::SemanticLogger.clear_appenders!
    @saved_appenders&.each { |appender| ::SemanticLogger.appenders << appender }
  end

  # Clear the isolated logger buffer (call this at the start of each test method)
  # Flushes any buffered logs first, then clears the buffer
  sig { params(io: StringIO).void }
  def clear_log_buffer(io)
    ::SemanticLogger.flush
    io.truncate(0)
    io.rewind
  end
end

# Explicitly set up integrations that may need manual setup
begin
  LogStruct::Integrations::Lograge.setup(LogStruct.config)
rescue NameError
  # ignore if not available
end

# Load all test support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }
