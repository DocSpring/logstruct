# typed: true
# frozen_string_literal: true

require "test_helper"

class PumaIntegrationUnitTest < Minitest::Test
  PUMA = LogStruct::Integrations::Puma

  def setup
    PUMA.send(:state_reset!)
    @original_argv = ARGV.dup
  end

  def teardown
    PUMA.send(:state_reset!)
    ARGV.replace(@original_argv)
  end

  def test_process_line_builds_started_log_from_boot_sequence
    started_logs = []

    LogStruct.stub(:info, ->(log) { started_logs << log }) do
      feed_boot_lines
    end

    started = started_logs.find { |log| log.is_a?(LogStruct::Log::Puma::Start) }

    refute_nil started, "expected a started log"
    assert_equal "single", started.mode
    assert_equal "test", started.environment
    assert_equal ["http://127.0.0.1:3000"], started.listening_addresses
    assert_equal 5, started.min_threads
    assert_equal 7, started.max_threads
  end

  def test_process_line_use_ctrl_c_fallback_infers_listening_address
    ARGV.replace(["server", "--port", "4000"])
    started_logs = []

    LogStruct.stub(:info, ->(log) { started_logs << log }) do
      PUMA.process_line("Use Ctrl-C to stop")
    end

    started = started_logs.find { |log| log.is_a?(LogStruct::Log::Puma::Start) }

    refute_nil started
    assert_includes started.listening_addresses, "tcp://127.0.0.1:4000"
  end

  def test_process_line_emits_shutdown
    shutdown_logs = []

    LogStruct.stub(:info, ->(log) { shutdown_logs << log }) do
      PUMA.process_line("=> Booting Puma")
      PUMA.process_line("- Gracefully stopping")
      PUMA.process_line("- Goodbye!")
    end

    shutdown = shutdown_logs.find { |log| log.is_a?(LogStruct::Log::Puma::Shutdown) }

    refute_nil shutdown
  end

  def test_process_line_returns_false_for_unhandled_input
    refute PUMA.process_line("unrecognized line")
  end

  # Stands in for Puma::ErrorLogger, which writes "<time> Rack app ("GET /path?query" - (ip)): error"
  class FakeErrorLogger
    attr_reader :written

    def info(options = {})
      (@written ||= []) << options
    end

    prepend LogStruct::Integrations::Puma::ErrorLoggerPatch
  end

  FakeRequest = Struct.new(:env)

  def test_request_errors_are_logged_as_structured_lines_without_the_query_string
    logged = []
    error = RuntimeError.new("boom")
    request = FakeRequest.new({"REQUEST_METHOD" => "GET", "REQUEST_PATH" => "/submissions/abc", "QUERY_STRING" => "token=secret"})
    error_logger = FakeErrorLogger.new

    LogStruct.stub(:error, ->(log) { logged << log }) do
      error_logger.info(error: error, req: request, text: "Rack app")
    end

    assert_nil error_logger.written, "Puma's plain text line was written too"
    log = logged.fetch(0)

    assert_equal [LogStruct::Source::Puma, RuntimeError, "boom"], [log.source, log.error_class, log.message]
    assert_equal({context: "Rack app", method: "GET", path: "/submissions/abc"}, log.additional_data)
    refute_includes log.serialize.to_s, "token=secret"
  end

  private

  def feed_boot_lines
    lines = [
      "Puma starting in single mode...",
      "Puma version: 6.6.1 (\"Return to Forever\")",
      "* Ruby version: ruby 3.4.5 (revision)",
      "*  Min threads: 5",
      "*  Max threads: 7",
      "*  Environment: test",
      "*          PID: 12345",
      "* Listening on http://127.0.0.1:3000"
    ]

    lines.each { |line| PUMA.process_line(line) }
  end
end
