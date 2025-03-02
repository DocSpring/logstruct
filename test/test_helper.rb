# typed: strict
# frozen_string_literal: true

# Start SimpleCov before requiring any other files
require "simplecov"
require "sorbet-runtime"

SimpleCov.start do
  T.bind(self, SimpleCov::Configuration)
  add_filter "test/"
  enable_coverage :branch
  primary_coverage :branch
end

require "minitest/autorun"
require "minitest/reporters"

# Use pretty reporters for better output
Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(
    color: true,
    detailed_skip: false
  )
]

# Require standard libraries
require "json"
require "ostruct"
require "debug"
require "logger"

# Require Rails
require "rails"
require "active_support/test_case"

# Create a minimal Rails application for testing
class TestApp < Rails::Application
  extend T::Sig

  sig { returns(T::Boolean) }
  def self.eager_load_frameworks
    false
  end

  config.eager_load = false
  config.logger = T.let(
    Logger.new($stdout).tap { |logger| logger.level = Logger::FATAL },
    Logger
  )

  # Configure Rails filter_parameters
  config.filter_parameters = T.let(
    [:password, :token, :secret, :key, :access, :auth, :credentials],
    T::Array[Symbol]
  )
end

# Initialize the application
Rails.application.initialize!

# Require the gem
require "logstruct"

# Configure LogStruct
LogStruct.configure do |config|
  config.enabled = true
  config.lograge_enabled = true
  config.actionmailer_integration_enabled = true
  config.activejob_integration_enabled = true
  config.sidekiq_integration_enabled = true
  config.shrine_integration_enabled = true
  config.active_storage_integration_enabled = true
  config.carrierwave_integration_enabled = true
  config.rack_middleware_enabled = true
  config.host_authorization_enabled = true

  # Email hash settings
  config.hash_salt = "test"
  config.hash_length = 12
end

# Load all test support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }
