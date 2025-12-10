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

  def test_setup_enables_sync_mode
    # Verify SemanticLogger is switched to sync mode when Puma integration runs.
    # This prevents the async processor thread from dying when Puma forks workers.
    config = LogStruct.config

    # Run Puma setup
    PUMA.setup(config)

    # Verify sync mode is enabled
    assert ::SemanticLogger.sync?, "SemanticLogger should be in sync mode after Puma setup"
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
