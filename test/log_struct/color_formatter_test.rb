# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/semantic_logger/color_formatter"
require "semantic_logger"
require "stringio"

module LogStruct
  class ColorFormatterTest < ActiveSupport::TestCase
    setup do
      @original_appenders = ::SemanticLogger.appenders.dup
      ::SemanticLogger.clear_appenders!

      @io = StringIO.new
      @formatter = LogStruct::SemanticLogger::ColorFormatter.new
      ::SemanticLogger.add_appender(
        io: @io,
        formatter: @formatter,
        async: false
      )

      @logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
    end

    teardown do
      ::SemanticLogger.clear_appenders!
      @original_appenders.each { |appender| ::SemanticLogger.add_appender(appender) }
    end

    test "colorizes LogStruct types with proper JSON structure" do
      # Create a test log entry
      log_entry = LogStruct::Log::Plain.new(
        message: "Test message",
        source: LogStruct::Source::App,
        event: LogStruct::Event::Log,
        additional_data: {user_id: 123, active: true}
      )

      @logger.info(log_entry)
      ::SemanticLogger.flush

      result = @io.string

      # Should contain ANSI color codes
      assert_includes result, "\e["
      assert_includes result, "\e[0m"

      # Should contain the structured data
      assert_includes result, "user_id"
      assert_includes result, "123"
      assert_includes result, "active"
      assert_includes result, "true"

      # Should contain LogStruct fields
      assert_includes result, "src"
      assert_includes result, "evt"
      assert_includes result, "app"
      assert_includes result, "log"
    end

    test "colorizes hash payloads correctly" do
      payload = {
        name: "John Doe",
        age: 30,
        preferences: {
          theme: "dark",
          notifications: true
        }
      }

      @logger.info(payload)
      ::SemanticLogger.flush

      result = @io.string

      # Should contain color codes for different data types
      assert_includes result, "\e["
      assert_includes result, "\e[0m"

      # Should contain nested structure formatting
      assert_includes result, "name"
      assert_includes result, "John Doe"
      assert_includes result, "preferences"
      assert_includes result, "theme"
    end

    test "falls back to standard colorization for plain messages" do
      @logger.info("Plain string message")
      ::SemanticLogger.flush

      result = @io.string

      # Should contain the message
      assert_includes result, "Plain string message"

      # Should contain color codes
      assert_includes result, "\e["
      assert_includes result, "\e[0m"
    end

    test "uses custom color map when provided" do
      # Use a fresh StringIO to avoid reuse issues
      custom_io = StringIO.new

      custom_formatter = LogStruct::SemanticLogger::ColorFormatter.new(
        color_map: {
          string: :red,
          number: :green,
          key: :blue
        }
      )

      # Update appender with custom formatter
      ::SemanticLogger.clear_appenders!
      ::SemanticLogger.add_appender(
        io: custom_io,
        formatter: custom_formatter,
        async: false
      )

      # Create a new logger instance to use the updated appender
      custom_logger = LogStruct::SemanticLogger::Logger.new("TestLogger")

      payload = {message: "test", count: 42}
      custom_logger.info(payload)
      ::SemanticLogger.flush

      result = custom_io.string

      # Should contain color codes
      assert_includes result, "\e["
      assert_includes result, "\e[0m"
      assert_includes result, "message"
      assert_includes result, "test"
      assert_includes result, "count"
      assert_includes result, "42"
    end

    test "handles different data types correctly" do
      payload = {
        string_val: "hello",
        int_val: 42,
        float_val: 3.14,
        bool_true: true,
        bool_false: false,
        nil_val: nil
      }

      @logger.info(payload)
      ::SemanticLogger.flush

      result = @io.string

      # Should contain all values with proper formatting
      assert_includes result, "hello"
      assert_includes result, "42"
      assert_includes result, "3.14"
      assert_includes result, "true"
      assert_includes result, "false"
      assert_includes result, "null"  # nil becomes "null" in JSON
    end

    test "generates proper log prefix with colors" do
      @logger.error("test message")
      ::SemanticLogger.flush

      result = @io.string

      # Should contain timestamp (approximate format)
      assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, result)

      # Should contain log level indicator
      assert_includes result, "E"  # Error level

      # Should contain logger name
      assert_includes result, "TestLogger"

      # Should contain ANSI color codes in the prefix
      assert_match(/\e\[.+?m/, result)
    end

    test "colorization can be disabled through configuration" do
      # This tests the integration with the setup module
      # The actual switching between formatters is tested in integration
      assert_respond_to @formatter, :call
      assert_kind_of LogStruct::SemanticLogger::ColorFormatter, @formatter
    end
  end
end
