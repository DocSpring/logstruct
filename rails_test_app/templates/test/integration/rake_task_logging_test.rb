# typed: true
# frozen_string_literal: true

require "test_helper"
require "open3"
require "timeout"

# Test that rake tasks in production have working logs when LogStruct auto-disables.
class RakeTaskLoggingTest < ActiveSupport::TestCase
  def test_rake_task_in_production_has_clean_logs
    # Simulate production rake task:
    # - RAILS_ENV=production (LogStruct would enable for servers)
    # - NOT a server process (rake task)
    # - LogStruct should auto-disable and fall back to clean Rails logging
    env = {
      "RAILS_ENV" => "production"
      # Don't set LOGSTRUCT_ENABLED - let auto-detection handle it
      # Rake tasks should auto-disable because no server is detected
    }

    # Run a rake task that logs something
    cmd = ["bundle", "exec", "rake", "logging:test_output"]

    stdout_output = nil
    stderr_output = nil

    Open3.popen3(env, *cmd, chdir: Rails.root.to_s) do |_stdin, stdout, stderr, wait_thr|
      begin
        Timeout.timeout(30) do
          wait_thr.value
        end
      rescue Timeout::Error
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue
          nil
        end

        flunk "Rake task timed out"
      end

      stdout_output = stdout.read
      stderr_output = stderr.read
    end

    combined_output = "#{stdout_output}\n#{stderr_output}"

    # Should NOT have hybrid format like: {message: "...", tags: [...]}
    # This pattern indicates the TaggedLogging monkey patch is wrapping
    # messages in hashes but they're not going through JSON formatter
    hybrid_pattern = /\{message:\s*["'].*["'],\s*tags:/

    refute_match hybrid_pattern,
      combined_output,
      "Found hybrid log format - LogStruct is half-enabled!\n" \
      "This means TaggedLogging monkey patch is active but SemanticLogger is not.\n" \
      "Output:\n#{combined_output}"

    # Should have the exact log messages (not silently dropped)
    assert_includes combined_output,
      "Test log message from rake task",
      "Expected to see 'Test log message from rake task' but logs appear to be dropped.\n" \
      "Output:\n#{combined_output}"

    # Should have the [custom_tag] prefix in clean Rails format
    assert_match(/\[custom_tag\].*Tagged test log message/,
      combined_output,
      "Expected to see '[custom_tag] Tagged test log message' in clean Rails format.\n" \
      "Output:\n#{combined_output}")
  end
end
