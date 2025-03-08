# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class LoggingTest < Minitest::Test
    def setup
      # Save original logger
      @original_logger = ::Rails.logger

      # Create a string buffer to capture log output
      @log_buffer = StringIO.new
      # Create a new logger that writes to our buffer
      @test_logger = ::Logger.new(@log_buffer)
      # Use our formatter to ensure structured logs
      @test_logger.formatter = LogStruct::Formatter.new

      # Set Rails.logger to our test logger
      ::Rails.logger = @test_logger
    end

    def teardown
      # Restore original logger
      ::Rails.logger = @original_logger
    end

    def test_debug_method_logs_struct_directly
      # Create a log struct
      log_struct = Log::Plain.new(
        message: "Debug message",
        source: Source::App,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0)
      )

      # Call the debug method
      LogStruct.debug(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message was logged correctly
      assert_equal "Debug message", parsed_log["msg"]
      assert_equal "app", parsed_log["src"]
      assert_equal "debug", parsed_log["lvl"]
    end

    def test_info_method_logs_struct_directly
      # Create a log struct
      log_struct = Log::Plain.new(
        message: "Info message",
        source: Source::App,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0)
      )

      # Call the info method
      LogStruct.info(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message was logged correctly
      assert_equal "Info message", parsed_log["msg"]
      assert_equal "app", parsed_log["src"]
      assert_equal "info", parsed_log["lvl"]
    end

    def test_warn_method_logs_struct_directly
      # Create a log struct
      log_struct = Log::Plain.new(
        message: "Warning message",
        source: Source::App,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0)
      )

      # Call the warn method
      LogStruct.warn(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message was logged correctly
      assert_equal "Warning message", parsed_log["msg"]
      assert_equal "app", parsed_log["src"]
      assert_equal "warn", parsed_log["lvl"]
    end

    def test_error_method_logs_struct_directly
      # Create a log struct
      log_struct = Log::Error.new(
        message: "Error message",
        source: Source::App,
        err_class: StandardError,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0)
      )

      # Call the error method
      LogStruct.error(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message was logged correctly
      assert_equal "Error message", parsed_log["msg"]
      assert_equal "app", parsed_log["src"]
      assert_equal "error", parsed_log["lvl"]
      assert_equal "StandardError", parsed_log["err_class"]
    end

    def test_fatal_method_logs_struct_directly
      # Create a log struct
      log_struct = Log::Error.new(
        message: "Fatal error",
        source: Source::App,
        err_class: RuntimeError,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0)
      )

      # Call the fatal method
      LogStruct.fatal(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message was logged correctly
      assert_equal "Fatal error", parsed_log["msg"]
      assert_equal "app", parsed_log["src"]
      assert_equal "fatal", parsed_log["lvl"]
      assert_equal "RuntimeError", parsed_log["err_class"]
    end

    def test_structured_logging_preserves_custom_fields
      # Create a log struct with additional data
      log_struct = Log::Plain.new(
        message: "Message with extra fields",
        source: Source::App,
        timestamp: Time.new(2023, 1, 1, 12, 0, 0),
        additional_data: {
          user_id: 123,
          action: "test",
          custom_field: "custom value"
        }
      )

      # Call the info method
      LogStruct.info(log_struct)

      # Verify the log output
      log_output = @log_buffer.string
      parsed_log = JSON.parse(log_output)

      # Verify the message and custom fields were logged correctly
      assert_equal "Message with extra fields", parsed_log["msg"]
      assert_equal 123, parsed_log["user_id"]
      assert_equal "test", parsed_log["action"]
      assert_equal "custom value", parsed_log["custom_field"]
    end
  end
end
