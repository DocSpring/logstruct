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

# Use pretty reporters with minimal output
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new(color: true)

# Require standard libraries
require "json"
require "ostruct"
require "debug"
require "logger"
require "fileutils"

# Ensure log directory exists
FileUtils.mkdir_p(File.expand_path("../log", __dir__))

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
    Logger.new(Rails.root.join("log/test.log").to_s).tap { |logger| logger.level = Logger::DEBUG },
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

# Load all test support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }
