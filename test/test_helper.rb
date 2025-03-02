# typed: false
# frozen_string_literal: true

# Start SimpleCov before requiring any other files
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/sorbet/"
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

# Set up a minimal Rails environment for testing
require "rails"
require "active_support/all"
require "json"
require "ostruct"
require "debug"

# Require the gem
require "logstruct"

# Sorbet type checking for tests
require "sorbet-runtime"

# Load all test support files
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].sort.each { |f| require f }

module TestHelper
  extend T::Sig

  # Mock Rails.logger for testing
  sig { params(blk: T.proc.params(logger: T.untyped).void).returns(T.untyped) }
  def setup_logger(&blk)
    logger = Minitest::Mock.new
    Rails.stub(:logger, logger) do
      yield logger if block_given?
    end
    logger
  end

  # Helper to create a structured log and verify its contents
  sig { params(log_class: T.class_of(T::Struct), params: T::Hash[Symbol, T.untyped], blk: T.nilable(T.proc.params(log: T.untyped).void)).returns(T.untyped) }
  def create_log(log_class, params = {}, &blk)
    log = log_class.new(**params)
    yield log if block_given?
    log
  end

  # Helper to verify log serialization
  sig { params(log: T.untyped, expected_keys: T::Array[Symbol]).void }
  def assert_log_serialization(log, expected_keys)
    serialized = log.serialize

    assert_instance_of Hash, serialized
    expected_keys.each do |key|
      assert_includes serialized.keys, key
    end
  end
end
