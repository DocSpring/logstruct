# typed: strict
# frozen_string_literal: true

# Start SimpleCov before requiring any other files
require "simplecov"
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

# Require Rails components
require "rails"
require "active_support"
require "active_job"
require "action_mailer"
require "globalid"

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
  config.rails = true
  config.sidekiq = true
  config.honeybadger = true
  config.bugsnag = true
  config.email_hash_salt = "test"
  config.email_hash_min_length = 5
end

# Sorbet type checking for tests
require "sorbet-runtime"

# Load all test support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }

module TestHelper
  extend T::Sig
  include Minitest::Assertions

  # For Minitest assertions
  sig { returns(Integer) }
  def assertions
    @assertions ||= T.let(0, T.nilable(Integer))
  end

  sig { params(value: Integer).returns(Integer) }
  def assertions=(value)
    @assertions = value
  end

  # Helper to create a structured log and verify its contents
  sig { params(log_data: T::Hash[Symbol, T.untyped], blk: T.nilable(T.proc.params(arg0: T::Hash[Symbol, T.untyped]).void)).returns(T::Hash[Symbol, T.untyped]) }
  def create_log(log_data = {}, &blk)
    log = {
      timestamp: Time.now.utc.iso8601(3),
      uuid: "123e4567-e89b-12d3-a456-426614174000"
    }.merge(log_data)

    yield log if Kernel.block_given?

    log
  end

  sig { params(klass: T.class_of(Object), obj: T.untyped).void }
  def assert_instance_of_with_msg(klass, obj)
    assert_instance_of klass, obj, "Expected #{obj.inspect} to be an instance of #{klass}"
  end

  sig { params(collection: T.untyped, obj: T.untyped).void }
  def assert_includes_with_msg(collection, obj)
    assert_includes collection, obj, "Expected #{collection.inspect} to include #{obj.inspect}"
  end
end
