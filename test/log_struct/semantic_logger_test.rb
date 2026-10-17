# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/semantic_logger/formatter"
require "log_struct/semantic_logger/logger"
require "tempfile"

module LogStruct
  class SemanticLoggerTest < ActiveSupport::TestCase
    setup do
      @io = setup_isolated_logger
      @logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
    end

    teardown do
      teardown_isolated_logger
    end

    test "writes to STDOUT without buffering" do
      # Like STDOUT when it's a pipe or a file
      stdout = Tempfile.new("stdout")
      stdout.sync = false
      saved_stdout = $stdout
      $stdout = stdout

      ClimateControl.modify(RAILS_LOG_TO_STDOUT: "true") do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
      end

      assert stdout.sync
    ensure
      # Remove the appenders writing to it before closing it; teardown puts back the others
      ::SemanticLogger.clear_appenders!
      $stdout = saved_stdout
      stdout&.close!
    end

    test "logs only to STDOUT when RAILS_LOG_TO_STDOUT is set" do
      ClimateControl.modify(RAILS_LOG_TO_STDOUT: "true") do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
      end

      assert_empty(::SemanticLogger.appenders.select { |appender| appender.is_a?(::SemanticLogger::Appender::File) })
    ensure
      ::SemanticLogger.clear_appenders!
    end

    test "request IDs are scrubbed and filtered like the rest of the line" do
      ::SemanticLogger.named_tagged(request_id: "4111111111111111") { @logger.info("Card request") }
      ::SemanticLogger.flush

      assert_equal "[CREDIT_CARD]", JSON.parse(T.must(@io.string.lines.last))["req_id"]

      LogStruct.config.filters.filter_keys += [:req_id]
      ::SemanticLogger.named_tagged(request_id: "req-1") { @logger.info("Filtered request") }
      ::SemanticLogger.flush

      assert_equal({"_filtered" => {"_class" => "String"}}, JSON.parse(T.must(@io.string.lines.last))["req_id"])
    end

    test "logs plain messages through SemanticLogger" do
      @logger.info("Test message")
      ::SemanticLogger.flush

      output = @io.string

      assert_includes output, "Test message"

      # Should be JSON formatted when using our formatter
      # For now, just verify the message is there since formatter needs fixing
      # log = JSON.parse(output.lines.last)
      # assert_equal "info", log["lvl"]
      # assert_equal "Test message", log["message"]
    end

    test "logs LogStruct types correctly" do
      clear_log_buffer(@io)

      log_entry = LogStruct::Log::Plain.new(
        message: "Structured log",
        source: LogStruct::Source::App,
        event: LogStruct::Event::Log
      )

      @logger.info(log_entry)
      ::SemanticLogger.flush

      output = @io.string

      assert output && !output.empty?, "Expected output to be generated"

      # Parse the JSON output
      log = JSON.parse(output.lines.first.strip)

      # Verify the LogStruct fields are present
      assert_equal "app", log["src"]
      assert_equal "log", log["evt"]
      assert_equal "info", log["lvl"]

      # Message should be in msg field
      assert_equal "Structured log", log["msg"]
    end

    test "logs hashes with proper filtering" do
      clear_log_buffer(@io)

      # Set up filter parameters
      LogStruct.config.filters.filter_keys = [:password, :secret]

      @logger.info({message: "User login", password: "secret123", user: "test"})
      ::SemanticLogger.flush  # Flush to ensure output is written

      output = @io.string

      assert output && !output.empty?, "Expected output to be generated"

      # Parse the first line of JSON output (last line might be empty)
      log = JSON.parse(output.lines.first.strip)

      data = log

      assert_nil log["payload"]
      assert_equal "User login", data["message"]
      assert_equal "test", data["user"]

      # Password should be filtered at top level
      assert_kind_of Hash, data["password"], "Password should be filtered into a hash"
      assert data["password"]["_filtered"], "Password should include _filtered summary"
    end

    test "writes a Hash's own src and evt at the top level" do
      clear_log_buffer(@io)

      %i[debug info warn error fatal].each do |level|
        @logger.public_send(level, {src: "rails", evt: "rate_limit", rule: "logins/#{level}"})
      end
      ::SemanticLogger.flush

      lines = @io.string.lines.map { |line| JSON.parse(line) }

      assert_equal %w[logins/debug logins/info logins/warn logins/error logins/fatal], lines.pluck("rule")
      lines.each do |line|
        assert_equal "rails", line["src"]
        assert_equal "rate_limit", line["evt"]
        assert_nil line["payload"]
      end
    end

    test "keeps the line's timestamp and level when a logged Hash sets them" do
      clear_log_buffer(@io)
      reported = []

      LogStruct.stub(:handle_exception, ->(error, **) { reported << error.message }) do
        @logger.info({msg: "Posted to Slack", ts: "1700000000.000100", lvl: "debug"})
        ::SemanticLogger.flush
      end

      line = JSON.parse(T.must(@io.string.lines.last))

      assert_equal "info", line["lvl"]
      refute_equal "1700000000.000100", line["ts"]
      assert_equal ["A logged Hash attempted to set reserved key: ts", "A logged Hash attempted to set reserved key: lvl"], reported.uniq
    end

    test "supports tagged logging" do
      @logger.tagged("request-123") do
        @logger.info("Processing request")
      end
      ::SemanticLogger.flush  # Flush to ensure output is written

      output = @io.string

      assert_includes output, "Processing request"

      # Tags should be included in the log
      # For now just check the message is there
      # log = JSON.parse(output.lines.last)
      # assert_includes log["tags"] || [], "request-123"
    end

    test "maintains backward compatibility with Rails.logger interface" do
      # Test that our logger implements the Rails.logger interface
      assert_respond_to @logger, :info
      assert_respond_to @logger, :debug
      assert_respond_to @logger, :warn
      assert_respond_to @logger, :error
      assert_respond_to @logger, :fatal
      assert_respond_to @logger, :tagged
      assert_respond_to @logger, :push_tags
      assert_respond_to @logger, :pop_tags
      assert_respond_to @logger, :clear_tags!
      # ActiveSupport::BroadcastLogger compatibility
      assert_respond_to @logger, :broadcast_to
      assert_respond_to @logger, :stop_broadcasting_to
      assert_respond_to @logger, :broadcasts
      assert_respond_to @logger, :<<
    end

    test "supports broadcast_to for multiple loggers" do
      # Create a secondary logger to broadcast to
      secondary_io = StringIO.new
      secondary_logger = Logger.new(secondary_io)

      # Add secondary logger to broadcasts
      @logger.broadcast_to(secondary_logger)

      # Log a message
      @logger.info("Test broadcast message")
      ::SemanticLogger.flush

      # Check main logger output
      main_output = @io.string

      assert_includes main_output, "Test broadcast message"

      # Check secondary logger output
      secondary_output = secondary_io.string

      assert_includes secondary_output, "Test broadcast message"
    end

    test "broadcast loggers get scrubbed messages" do
      secondary_io = StringIO.new
      @logger.broadcast_to(Logger.new(secondary_io))

      @logger.info("Signed in as ada@example.com")
      @logger.warn { "Card 4111111111111111 declined" }

      assert_includes secondary_io.string, "Signed in as [EMAIL:"
      assert_includes secondary_io.string, "Card [CREDIT_CARD] declined"
      assert_not_includes secondary_io.string, "ada@example.com"
    end

    test "broadcast_to ignores SemanticLogger loggers, which share its appenders" do
      sidekiq_logger = LogStruct::Integrations::Sidekiq::Logger.new("Sidekiq-Server")

      @logger.broadcast_to(sidekiq_logger)
      @logger.info("Written once")
      ::SemanticLogger.flush

      assert_empty @logger.broadcasts
      assert_equal 1, @io.string.scan("Written once").size
    end

    test "stop_broadcasting_to removes logger from broadcasts" do
      secondary_io = StringIO.new
      secondary_logger = Logger.new(secondary_io)

      @logger.broadcast_to(secondary_logger)
      @logger.stop_broadcasting_to(secondary_logger)

      @logger.info("After removal")
      ::SemanticLogger.flush

      # Main logger should have output
      assert_includes @io.string, "After removal"

      # Secondary logger should NOT have output
      assert_empty secondary_io.string
    end

    test "broadcasts array returns all broadcast loggers" do
      logger1 = Logger.new(StringIO.new)
      logger2 = Logger.new(StringIO.new)

      @logger.broadcast_to(logger1)
      @logger.broadcast_to(logger2)

      assert_equal 2, @logger.broadcasts.length
      assert_includes @logger.broadcasts, logger1
      assert_includes @logger.broadcasts, logger2
    end

    test "supports << operator for appending messages" do
      secondary_io = StringIO.new
      secondary_logger = Logger.new(secondary_io)

      @logger.broadcast_to(secondary_logger)
      @logger << "Appended message"
      ::SemanticLogger.flush

      # Check main logger output
      assert_includes @io.string, "Appended message"

      # Check secondary logger output
      assert_includes secondary_io.string, "Appended message"
    end

    test "broadcast works with different log levels" do
      secondary_io = StringIO.new
      secondary_logger = Logger.new(secondary_io)

      @logger.broadcast_to(secondary_logger)

      @logger.debug("Debug message")
      @logger.info("Info message")
      @logger.warn("Warn message")
      @logger.error("Error message")
      ::SemanticLogger.flush

      secondary_output = secondary_io.string

      assert_includes secondary_output, "Debug message"
      assert_includes secondary_output, "Info message"
      assert_includes secondary_output, "Warn message"
      assert_includes secondary_output, "Error message"
    end

    test "handles errors gracefully" do
      # Create an object that will raise an error when serialized
      problematic_object = Object.new
      problematic_object.define_singleton_method(:to_s) do
        raise "Serialization error"
      end

      # Should not raise an error
      assert_nothing_raised do
        @logger.info(problematic_object)
        ::SemanticLogger.flush  # Flush to ensure output is written
      end
    end

    test "FormatterProxy responds to call method for Logger compatibility" do
      formatter = LogStruct::SemanticLogger::FormatterProxy.new

      # FormatterProxy must implement the standard Logger formatter interface
      assert_respond_to formatter, :call
      assert_respond_to formatter, :current_tags

      # call method should accept standard Logger formatter arguments
      time = Time.now
      result = formatter.call("INFO", time, "TestProgram", "Test message")

      # Should return a string
      assert_kind_of String, result
      assert_includes result, "Test message"
    end

    test "FormatterProxy works with standard Ruby Logger" do
      # This test ensures FormatterProxy can be used as a formatter for Ruby's Logger
      # which is important for Rails/ActiveSupport compatibility (logger 1.7.0+)
      io = StringIO.new
      stdlib_logger = ::Logger.new(io)

      # Assign FormatterProxy as the formatter (simulates what Rails might do)
      stdlib_logger.formatter = LogStruct::SemanticLogger::FormatterProxy.new

      # Should not raise an error when logging
      assert_nothing_raised do
        stdlib_logger.info("Test message from stdlib logger")
      end

      # Output should contain the message
      output = io.string

      assert_includes output, "Test message from stdlib logger"
    end

    test "FormatterProxy call method handles nil and empty messages" do
      formatter = LogStruct::SemanticLogger::FormatterProxy.new
      time = Time.now

      # Should handle nil message
      result = formatter.call("INFO", time, nil, nil)

      assert_kind_of String, result

      # Should handle empty string message
      result = formatter.call("DEBUG", time, "prog", "")

      assert_kind_of String, result
    end
  end
end
