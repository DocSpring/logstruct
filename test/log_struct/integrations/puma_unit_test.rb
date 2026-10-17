# typed: true
# frozen_string_literal: true

require "test_helper"
require "timeout"

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

  def test_install_patches_skips_when_puma_is_not_installed
    installed = PUMA::STATE[:installed]
    PUMA::STATE[:installed] = false

    PUMA.stub(:require, ->(_name) { raise LoadError, "cannot load such file -- puma" }) do
      PUMA.install_patches!
    end

    refute PUMA::STATE[:installed]
  ensure
    PUMA::STATE[:installed] = installed
  end

  def test_a_problem_in_the_puma_integration_is_a_logstruct_error
    handled = []
    error = RuntimeError.new("patch broke")

    LogStruct.stub(:server_mode?, true) do
      LogStruct.stub(:handle_exception, ->(e, source:, context: nil) { handled << [e, source, context] }) do
        PUMA.handle_integration_error(error)
      end
    end

    assert_equal [[error, LogStruct::Source::Internal, {integration: :puma}]], handled
  end

  def test_puma_lifecycle_initializer_does_nothing_when_logstruct_is_disabled
    initializer = LogStruct::Railtie.instance.initializers.find { |i| i.name == "logstruct.puma_lifecycle" }
    logged = []

    LogStruct.stub(:enabled?, false) do
      LogStruct.stub(:server_mode?, true) do
        LogStruct.stub(:info, ->(log) { logged << log }) do
          T.must(initializer).run(Rails.application)
        end
      end
    end

    assert_empty logged
  end

  def test_shutdown_trap_logs_then_runs_the_previous_handler
    previous_calls = []
    shutdowns = []
    original = Signal.trap("USR2") { |signal_number| previous_calls << signal_number }

    PUMA.stub(:emit_shutdown!, ->(message) { shutdowns << message }) do
      PUMA.trap_shutdown_signal("USR2")
      Process.kill("USR2", Process.pid)
      Timeout.timeout(2) { sleep 0.01 while previous_calls.empty? }
    end

    assert_equal ["USR2"], shutdowns
    assert_equal [Signal.list.fetch("USR2")], previous_calls
  ensure
    Signal.trap("USR2", original || "DEFAULT")
  end

  # A real signal in a child process: the default action, EXIT and IGNORE can't be stubbed
  # (stubbing Signal.trap breaks the debug gem's trap interceptor for later tests)
  def test_shutdown_trap_does_what_the_signal_does_by_default
    output = in_child_process do |out|
      send_signal_after_trapping("DEFAULT", out)
      out.write("not stopped")
    rescue SignalException => e
      out.write("stopped by #{e.signm}")
    end

    assert_equal "logged USR2; stopped by SIGUSR2", output
  end

  def test_shutdown_trap_exits_when_the_previous_handler_was_exit
    output = in_child_process do |out|
      send_signal_after_trapping("EXIT", out)
      out.write("not stopped")
    rescue SystemExit
      out.write("exited")
    end

    assert_equal "logged USR2; exited", output
  end

  def test_shutdown_trap_carries_on_when_the_signal_was_ignored
    output = in_child_process do |out|
      send_signal_after_trapping("IGNORE", out, wait: 0.2)
      out.write("still running")
    end

    assert_equal "logged USR2; still running", output
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

    assert_instance_of LogStruct::Log::Puma::Error, log
    assert_equal [LogStruct::Source::Puma, RuntimeError, "boom"], [log.source, log.error_class, log.message]
    assert_equal ["Rack app", "GET", "/submissions/abc"], [log.error_context, log.http_method, log.path]
    assert_nil log.additional_data
    assert_equal({src: "puma", evt: "error", error_context: "Rack app", method: "GET", path: "/submissions/abc"},
      log.serialize.slice(:src, :evt, :error_context, :method, :path))
    refute_includes log.serialize.to_s, "token=secret"
  end

  def test_request_errors_other_than_standard_errors_are_logged_too
    logged = []
    error = NotImplementedError.new("not yet")
    error_logger = FakeErrorLogger.new

    LogStruct.stub(:error, ->(log) { logged << log }) do
      error_logger.info(error: error, req: FakeRequest.new({"REQUEST_METHOD" => "POST", "PATH_INFO" => "/x"}), text: "Rack app")
    end

    assert_nil error_logger.written
    assert_equal NotImplementedError, logged.fetch(0).error_class
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

  def send_signal_after_trapping(previous_handler, out, wait: 2)
    PUMA.stub(:emit_shutdown!, ->(message) { out.write("logged #{message}; ") }) do
      Signal.trap("USR2", previous_handler)
      PUMA.trap_shutdown_signal("USR2")
      Process.kill("USR2", Process.pid)
      sleep wait
    end
  end

  # Runs the block in a forked child and returns what it wrote. exit! skips the child's at_exit hooks
  # (Minitest, SimpleCov).
  def in_child_process
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      begin
        yield writer
      rescue Exception => e # rubocop:disable Lint/RescueException
        writer.write("#{e.class}: #{e.message}")
      ensure
        writer.close
        exit!(0)
      end
    end
    writer.close
    Process.wait(pid)
    reader.read
  ensure
    reader&.close
  end
end
