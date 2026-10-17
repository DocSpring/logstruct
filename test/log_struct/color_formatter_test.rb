# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/semantic_logger/color_formatter"
require "semantic_logger"
require "stringio"

module LogStruct
  class ColorFormatterTest < ActiveSupport::TestCase
    setup do
      @io = StringIO.new
      @saved_appenders = ::SemanticLogger.appenders.dup
      @formatter = LogStruct::SemanticLogger::ColorFormatter.new

      clear_test_appenders
      ::SemanticLogger.add_appender(
        io: @io,
        formatter: @formatter,
        async: false
      )

      @logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
    end

    teardown do
      clear_test_appenders
      @saved_appenders&.each { |appender| ::SemanticLogger.appenders << appender }
      ::SemanticLogger::Logger.processor.start
    end

    test "colorizes LogStruct types with proper JSON structure" do
      clear_log_buffer(@io)

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
      clear_log_buffer(@io)

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
      clear_log_buffer(@io)

      @logger.info("Plain string message")
      ::SemanticLogger.flush

      result = @io.string

      # Should contain the message
      assert_includes result, "Plain string message"

      # Should contain color codes
      assert_includes result, "\e["
      assert_includes result, "\e[0m"
    end

    test "scrubs plain messages, payloads, exceptions and tags" do
      clear_log_buffer(@io)

      @logger.tagged("ada@example.com") do
        @logger.info("Signed in as bob@example.com")
        @logger.error("Failed", RuntimeError.new("no card 4111111111111111"))
      end
      ::SemanticLogger.flush

      result = @io.string

      assert_includes result, "Signed in as [EMAIL:"
      assert_not_includes result, "@example.com"
      assert_not_includes result, "4111111111111111"
    end

    test "filters named tags and Hash lines as the JSON lines are filtered" do
      clear_log_buffer(@io)

      @logger.tagged(password: "pr-named-tag-value", user_id: 7) do
        @logger.info("Plain line")
        @logger.info("Hash line", {evt: "checkout", api_key: "pr-hash-value"})
      end
      ::SemanticLogger.flush

      result = @io.string

      assert_not_includes result, "pr-named-tag-value"
      assert_not_includes result, "pr-hash-value"
      assert_includes result, "_filtered"
      assert_includes result, "user_id: 7"
      # A Hash line has the message, and the named tags in ctx, as its JSON line does
      assert_includes result, "Hash line"
      assert_match(/ctx: \{.*user_id: 7/m, result.gsub(/\e\[\d+m/, ""))
      assert_not_includes result, "\n\n"
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
      clear_test_appenders
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

    test "a params error's colored exception and causes leave out the input its parser quoted" do
      parse_error = assert_raises(ActionDispatch::Http::Parameters::ParseError) do
        JSON.parse('{"password":synthetic-raw-secret}')
      rescue JSON::ParserError
        raise ActionDispatch::Http::Parameters::ParseError, "Error occurred while parsing request parameters"
      end

      LogStruct::SemanticLogger::Logger.new("TestLogger").error("Sign-in failed", parse_error)
      ::SemanticLogger.flush

      assert_includes @io.string, "Error occurred while parsing request parameters"
      assert_includes @io.string, "JSON::ParserError: (left out: it quotes the request's input)"
      assert_not_includes @io.string, "synthetic-raw-secret"
    end

    test "a color map changes only the colors it names" do
      io = StringIO.new
      clear_test_appenders
      ::SemanticLogger.add_appender(io: io, formatter: LogStruct::SemanticLogger::ColorFormatter.new(color_map: {key: :red}), async: false)

      LogStruct::SemanticLogger::Logger.new("TestLogger").info({plan: "pro", count: 42})
      ::SemanticLogger.flush

      assert_includes io.string, "\e[31mplan\e[0m"
      assert_includes io.string, "\e[32mpro\e[0m"
      assert_includes io.string, "\e[34m42\e[0m"
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
      clear_log_buffer(@io)

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
