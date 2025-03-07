# typed: true
# frozen_string_literal: true

require "test_helper"
require "stringio"

module LogStruct
  class LoggerUtilsTest < ActiveSupport::TestCase
    setup do
      @original_rails_logger = ::Rails.logger
      @original_rails_env = ::Rails.env
      @original_rails_root = ::Rails.root
      @original_rails_log_to_stdout = ENV["RAILS_LOG_TO_STDOUT"]

      # Create a test logger for testing
      @test_logger = ::Logger.new($stdout)
    end

    teardown do
      ::Rails.logger = @original_rails_logger
      ENV["RAILS_LOG_TO_STDOUT"] = @original_rails_log_to_stdout
    end

    # ===== determine_log_target tests =====

    def test_determine_log_target_with_original_logger
      test_io = StringIO.new
      logger = ::Logger.new(test_io)

      target = LoggerUtils.determine_log_target(logger)

      assert_equal test_io, target
    end

    def test_determine_log_target_with_rails_logger
      test_io = StringIO.new
      rails_logger = ::Logger.new(test_io)
      ::Rails.logger = rails_logger

      target = LoggerUtils.determine_log_target(nil)

      assert_equal test_io, target
    end

    def test_determine_log_target_with_stdout_env
      # Create a mock Rails logger with no logdev
      # First store original logdev
      original_logdev = ::Rails.logger.instance_variable_get(:@logdev)

      # Set up Rails logger to have nil logdev
      rails_logger = ::Logger.new(StringIO.new)
      rails_logger.remove_instance_variable(:@logdev) if rails_logger.instance_variable_defined?(:@logdev)
      ::Rails.logger = rails_logger

      # Set the RAILS_LOG_TO_STDOUT env var
      ENV["RAILS_LOG_TO_STDOUT"] = "1"

      target = LoggerUtils.determine_log_target(nil)

      assert_equal $stdout, target

      # Restore original logdev
      ::Rails.logger.instance_variable_set(:@logdev, original_logdev) if original_logdev
    end

    def test_determine_log_target_in_test_env
      # Create a Rails logger with no logdev
      rails_logger = ::Logger.new(StringIO.new)
      rails_logger.remove_instance_variable(:@logdev) if rails_logger.instance_variable_defined?(:@logdev)
      ::Rails.logger = rails_logger

      # Remove the STDOUT env var
      ENV.delete("RAILS_LOG_TO_STDOUT")

      # Set up test environment
      ::Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
        # Set up Rails.root to return a predictable path
        test_path = File.expand_path("../../tmp/test_root", __dir__)
        path_obj = Pathname.new(test_path)

        ::Rails.stub(:root, path_obj) do
          target = LoggerUtils.determine_log_target(nil)

          assert_equal "#{test_path}/log/test.log", target
        end
      end
    end

    def test_determine_log_target_default_to_stdout
      # Create a Rails logger with no logdev
      rails_logger = ::Logger.new(StringIO.new)
      rails_logger.remove_instance_variable(:@logdev) if rails_logger.instance_variable_defined?(:@logdev)
      ::Rails.logger = rails_logger

      # Remove the STDOUT env var
      ENV.delete("RAILS_LOG_TO_STDOUT")

      # Set up non-test environment
      ::Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
        target = LoggerUtils.determine_log_target(nil)

        assert_equal $stdout, target
      end
    end

    # ===== determine_log_level tests =====

    def test_determine_log_level_with_original_logger
      # Set up logger with known level
      test_logger = ::Logger.new(StringIO.new)
      test_logger.level = ::Logger::DEBUG

      level = LoggerUtils.determine_log_level(test_logger)

      assert_equal ::Logger::DEBUG, level
    end

    def test_determine_log_level_with_rails_logger
      # Set up Rails logger with known level
      ::Rails.logger.level = ::Logger::WARN

      level = LoggerUtils.determine_log_level(nil)

      assert_equal ::Logger::WARN, level
    end

    def test_determine_log_level_with_unresponsive_logger
      # We need to use a properly typed logger but mock it to be unresponsive
      unresponsive_logger = ::Logger.new(StringIO.new)

      # Set up Rails logger with known level
      ::Rails.logger.level = ::Logger::INFO

      # Mock the respond_to? method to return false for :level
      unresponsive_logger.define_singleton_method(:respond_to?) do |method_name|
        method_name != :level
      end

      level = LoggerUtils.determine_log_level(unresponsive_logger)

      assert_equal ::Logger::INFO, level
    end

    # ===== create_logger tests =====

    def test_create_logger_with_default_options
      test_io = StringIO.new
      test_level = ::Logger::ERROR

      # Set up Rails logger to use our test IO with a known level
      ::Rails.logger = ::Logger.new(test_io)
      ::Rails.logger.level = test_level

      # We'll use the real LogStruct::Logger class but stub the new method
      # to verify what parameters it receives
      real_new = LogStruct::Logger.method(:new)

      begin
        device_received = T.let(nil, T.nilable(String))
        level_received = T.let(nil, T.nilable(Integer))

        LogStruct::Logger.define_singleton_method(:new) do |device, shift_age = 0, shift_size = 1048576, level: nil|
          device_received = device
          level_received = level
          # Create a partially initialized object that passes type checks
          logger = LogStruct::Logger.allocate
          # We need to initialize the underlying member variables that would be set in initialize
          logger.instance_variable_set(:@level, level || ::Logger::DEBUG)
          logger.instance_variable_set(:@logdev, ::Logger::LogDevice.new(StringIO.new))
          logger
        end

        LoggerUtils.create_logger(LogStruct::Logger)

        # Verify params
        assert_equal test_io, device_received
        assert_equal test_level, level_received
      ensure
        # Restore original method
        LogStruct::Logger.singleton_class.send(:remove_method, :new)
        LogStruct::Logger.define_singleton_method(:new, real_new)
      end
    end

    def test_create_logger_with_provided_options
      custom_io = StringIO.new
      custom_level = ::Logger::INFO
      options = {logdev: custom_io, level: custom_level}

      # We'll use the real LogStruct::Logger class but stub the new method
      real_new = LogStruct::Logger.method(:new)

      begin
        device_received = T.let(nil, T.nilable(String))
        level_received = T.let(nil, T.nilable(Integer))

        LogStruct::Logger.define_singleton_method(:new) do |device, shift_age = 0, shift_size = 1048576, level: nil|
          device_received = device
          level_received = level
          # Create a partially initialized object that passes type checks
          logger = LogStruct::Logger.allocate
          # We need to initialize the underlying member variables that would be set in initialize
          logger.instance_variable_set(:@level, level || ::Logger::DEBUG)
          logger.instance_variable_set(:@logdev, ::Logger::LogDevice.new(StringIO.new))
          logger
        end

        # We intentionally don't stub determine_* methods
        # to verify they don't get called with explicit options
        LoggerUtils.create_logger(LogStruct::Logger, options: options)

        # Verify params
        assert_equal custom_io, device_received
        assert_equal custom_level, level_received
      ensure
        # Restore original method
        LogStruct::Logger.singleton_class.send(:remove_method, :new)
        LogStruct::Logger.define_singleton_method(:new, real_new)
      end
    end

    def test_create_logger_with_original_logger
      # Set up an original LogStruct::Logger for testing
      original_io = StringIO.new
      original_level = ::Logger::WARN
      original_logger = LogStruct::Logger.new(original_io, level: original_level)

      # Stub the determine methods to control their return values
      LoggerUtils.stub(:determine_log_target, original_io) do
        LoggerUtils.stub(:determine_log_level, original_level) do
          # We'll use the real LogStruct::Logger class but stub the new method
          real_new = LogStruct::Logger.method(:new)

          begin
            device_received = T.let(nil, T.nilable(String))
            level_received = T.let(nil, T.nilable(Integer))

            LogStruct::Logger.define_singleton_method(:new) do |device, shift_age = 0, shift_size = 1048576, level: nil|
              device_received = device
              level_received = level
              # Create a partially initialized object that passes type checks
              logger = LogStruct::Logger.allocate
              # We need to initialize the underlying member variables that would be set in initialize
              logger.instance_variable_set(:@level, level || ::Logger::DEBUG)
              logger.instance_variable_set(:@logdev, ::Logger::LogDevice.new(StringIO.new))
              logger
            end

            # Pass the original_logger to test this code path
            LoggerUtils.create_logger(LogStruct::Logger, original_logger: original_logger)

            # Verify params
            assert_equal original_io, device_received
            assert_equal original_level, level_received
          ensure
            # Restore original method
            LogStruct::Logger.singleton_class.send(:remove_method, :new)
            LogStruct::Logger.define_singleton_method(:new, real_new)
          end
        end
      end
    end

    def test_create_logger_with_partial_options
      # Custom options with only level provided
      custom_level = ::Logger::INFO
      test_io = StringIO.new
      options = {level: custom_level}

      # Stub determine_log_target to return a known value
      LoggerUtils.stub(:determine_log_target, test_io) do
        # We'll use the real LogStruct::Logger class but stub the new method
        real_new = LogStruct::Logger.method(:new)

        begin
          device_received = T.let(nil, T.nilable(String))
          level_received = T.let(nil, T.nilable(Integer))

          LogStruct::Logger.define_singleton_method(:new) do |device, shift_age = 0, shift_size = 1048576, level: nil|
            device_received = device
            level_received = level
            # Create a partially initialized object that passes type checks
            logger = LogStruct::Logger.allocate
            # We need to initialize the underlying member variables that would be set in initialize
            logger.instance_variable_set(:@level, level || ::Logger::DEBUG)
            logger.instance_variable_set(:@logdev, ::Logger::LogDevice.new(StringIO.new))
            logger
          end

          # Use partial options to test this code path
          LoggerUtils.create_logger(LogStruct::Logger, options: options)

          # Verify params
          assert_equal test_io, device_received
          assert_equal custom_level, level_received
        ensure
          # Restore original method
          LogStruct::Logger.singleton_class.send(:remove_method, :new)
          LogStruct::Logger.define_singleton_method(:new, real_new)
        end
      end
    end
  end
end
