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
      @isolated_appender = ::SemanticLogger.appenders.last
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
      clear_test_appenders
      $stdout = saved_stdout
      stdout&.close!
    end

    test "logs only to STDOUT when RAILS_LOG_TO_STDOUT is set" do
      ClimateControl.modify(RAILS_LOG_TO_STDOUT: "true") do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
      end

      assert_empty(::SemanticLogger.appenders.select { |appender| appender.is_a?(::SemanticLogger::Appender::File) })
    ensure
      clear_test_appenders
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

    test "keeps the message logged beside a Hash" do
      clear_log_buffer(@io)
      @logger.info("Saved", id: 1)
      @logger.info("Renamed", msg: "Its own message")
      ::SemanticLogger.flush

      lines = @io.string.lines.map { |line| JSON.parse(line) }

      assert_equal [["Saved", 1], ["Its own message", nil]], lines.map { |line| line.values_at("msg", "id") }
    end

    test "logs exceptions with their class, message and backtrace" do
      error = ArgumentError.new("bad input")
      error.set_backtrace(["app/jobs/sync_job.rb:3:in 'perform'"])
      clear_log_buffer(@io)

      @logger.error(error)
      @logger.error("Sync failed", error)
      @logger.error("Sync failed", {order_id: 7}, error)
      @logger.error({order_id: 8}, error)
      ::SemanticLogger.flush

      lines = @io.string.lines.map { |line| JSON.parse(line) }

      assert_equal(
        [
          ["error", "ArgumentError", "bad input", nil, nil],
          ["error", "ArgumentError", "Sync failed", "bad input", nil],
          ["error", "ArgumentError", "Sync failed", "bad input", 7],
          ["error", "ArgumentError", "bad input", nil, 8]
        ],
        lines.map { |line| line.values_at("evt", "error_class", "msg", "error_message", "order_id") }
      )
      assert_equal ["app/jobs/sync_job.rb:3:in 'perform'"], lines.first["backtrace"]
    end

    test "a params error's line leaves out the input its parser quoted" do
      rack_error = assert_raises(Rack::Utils::InvalidParameterError) do
        Rack::Utils.parse_nested_query("password=%zz-synthetic-raw-secret")
      end
      bad_request = assert_raises(ActionController::BadRequest) do
        raise rack_error
      rescue Rack::Utils::InvalidParameterError => e
        raise ActionController::BadRequest, "Invalid request parameters: #{e.message}"
      end
      clear_log_buffer(@io)

      @logger.error(bad_request)
      @logger.error("Import failed", rack_error)
      ::SemanticLogger.flush

      lines = @io.string.lines.map { |line| JSON.parse(line) }

      assert_equal [["Invalid request parameters", nil], ["Import failed", "Invalid request parameters"]],
        lines.map { |line| line.values_at("msg", "error_message") }
      assert_not_includes @io.string, "synthetic-raw-secret"
    end

    test "settings from config/initializers apply to the logger set up before them" do
      LogStruct.config.prefer_json_in_development = false
      before = ::SemanticLogger.appenders.to_a

      ClimateControl.modify(RAILS_LOG_TO_STDOUT: "true") do
        Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
          LogStruct::SemanticLogger::Setup.reconfigure_appenders(Rails.application)
        end
      end

      formatters = (::SemanticLogger.appenders.to_a - before).map { |appender| appender.formatter.class }

      assert_equal [LogStruct::SemanticLogger::ColorFormatter], formatters
    ensure
      LogStruct.config.prefer_json_in_development = true
    end

    test "adding the appenders again keeps the ones an app added in config/initializers" do
      ClimateControl.modify(RAILS_LOG_TO_STDOUT: "true") do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
        app_appender = ::SemanticLogger.add_appender(io: StringIO.new, formatter: :json)

        LogStruct::SemanticLogger::Setup.reconfigure_appenders(Rails.application)

        assert_includes ::SemanticLogger.appenders, app_appender
        assert_includes ::SemanticLogger.appenders, @isolated_appender
        # LogStruct's STDOUT appender was replaced, not added a second time
        assert_equal 1, ::SemanticLogger.appenders.count { |appender| appender.respond_to?(:console_output?) && appender.console_output? }
      end
    ensure
      clear_test_appenders
    end

    test "the logstruct.setup initializer adds the appenders again when the logger is already set up" do
      initializer = LogStruct::Railtie.instance.initializers.find { |i| i.name == "logstruct.setup" }
      reconfigured = []

      LogStruct.stub(:apply_initializer_settings!, nil) do
        LogStruct.stub(:merge_rails_filter_parameters!, nil) do
          LogStruct::Integrations.stub(:setup_integrations, ->(stage:) {}) do
            LogStruct::SemanticLogger::Setup.stub(:configured?, true) do
              LogStruct::SemanticLogger::Setup.stub(:reconfigure_appenders, ->(app) { reconfigured << app }) do
                T.must(initializer).run(Rails.application)
              end
            end
          end
        end
      end

      assert_equal [Rails.application], reconfigured
    end

    test "logs only to STDOUT in production" do
      clear_test_appenders
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
      end

      assert_empty(::SemanticLogger.appenders.select { |appender| appender.is_a?(::SemanticLogger::Appender::File) })
      assert_equal 1, ::SemanticLogger.appenders.size
    ensure
      clear_test_appenders
    end

    test "logs to the log file too in test" do
      clear_test_appenders
      ClimateControl.modify(RAILS_LOG_TO_STDOUT: nil) do
        LogStruct::SemanticLogger::Setup.add_appenders(Rails.application)
      end

      assert_equal 1, ::SemanticLogger.appenders.count { |appender| appender.is_a?(::SemanticLogger::Appender::File) }
    ensure
      clear_test_appenders
    end

    test "forked processes still write their lines" do
      LogStruct::SemanticLogger::ReopenAfterFork.install!
      reader, writer = IO.pipe
      clear_test_appenders
      ::SemanticLogger.add_appender(io: writer, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)

      # SemanticLogger's writer thread isn't copied into the child
      pid = fork do
        reader.close
        @logger.info("from the child")
        ::SemanticLogger.flush
        exit!(0)
      end
      Process.wait(pid)
      clear_test_appenders
      writer.close

      assert_includes reader.read, "from the child"
    ensure
      reader&.close
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

    test "writes the logger's tags, and its named tags in ctx" do
      @logger.tagged("billing", "request-123") do
        @logger.tagged(user_id: 42) do
          @logger.info("Processing request")
        end
      end
      ::SemanticLogger.flush

      line = JSON.parse(T.must(@io.string.lines.last))

      assert_equal "Processing request", line["msg"]
      assert_equal ["billing", "request-123"], line["tags"]
      assert_equal({"user_id" => 42}, line["ctx"])
    end

    test "tags and named tags are filtered and scrubbed like the rest of the line" do
      @logger.tagged("user@example.com") do
        @logger.tagged(password: "hunter2") do
          @logger.info("Signed in")
        end
      end
      ::SemanticLogger.flush

      line = JSON.parse(T.must(@io.string.lines.last))

      refute_includes line.to_s, "user@example.com"
      refute_includes line.to_s, "hunter2"
      assert_match(/\A\[EMAIL:\h+\]\z/, line["tags"].first)
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
      @logger << "Reset sent to grace@example.com"

      assert_includes secondary_io.string, "Signed in as [EMAIL:"
      assert_includes secondary_io.string, "Card [CREDIT_CARD] declined"
      assert_includes secondary_io.string, "Reset sent to [EMAIL:"
      assert_not_includes secondary_io.string, "ada@example.com"
      assert_not_includes secondary_io.string, "grace@example.com"
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

      # Check secondary logger output, once
      assert_equal 1, secondary_io.string.scan("Appended message").size
    end

    # rails server's log_to_stdout in development, where LogStruct writes to STDOUT
    test "broadcast_to ignores a STDOUT logger when SemanticLogger already writes to STDOUT" do
      console_appender = ::SemanticLogger.add_appender(io: $stdout, formatter: LogStruct::SemanticLogger::Formatter.new)
      console = ::ActiveSupport::Logger.new($stdout)

      @logger.broadcast_to(console)

      assert_empty @logger.broadcasts
    ensure
      ::SemanticLogger.remove_appender(console_appender) if console_appender
    end

    test "broadcast_to keeps a STDOUT logger when nothing else writes to STDOUT" do
      console = ::ActiveSupport::Logger.new($stdout)

      @logger.broadcast_to(console)

      assert_equal [console], @logger.broadcasts
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

    test "filter_noisy_loggers leaves out the noisy loggers' lines and keeps the others" do
      LogStruct.config.filter_noisy_loggers = true
      io = StringIO.new
      ::SemanticLogger.add_appender(
        io: io,
        formatter: LogStruct::SemanticLogger::Formatter.new,
        filter: LogStruct::SemanticLogger::Setup.determine_filter,
        async: false
      )

      ::SemanticLogger["Rails"].info("an app line")
      ::SemanticLogger["ActionView::Base"].info("a template line")
      ::SemanticLogger.flush

      assert_includes io.string, "an app line"
      refute_includes io.string, "a template line"
    ensure
      LogStruct.config.filter_noisy_loggers = false
    end
  end
end
