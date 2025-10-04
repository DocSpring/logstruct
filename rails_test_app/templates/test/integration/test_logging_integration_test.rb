# typed: true

require "test_helper"
require "open3"
require "timeout"
require "fileutils"

class TestLoggingIntegrationTest < ActiveSupport::TestCase
  def test_test_logs_go_to_file_not_stdout
    # Clean up log file before test
    log_file = Rails.root.join("log/test.log")
    FileUtils.rm_f(log_file)
    FileUtils.touch(log_file)

    env = {
      "LOGSTRUCT_ENABLED" => "true",
      "RAILS_ENV" => "test"
    }

    # Run a simple test that will generate logs
    cmd = ["bundle", "exec", "rails", "test", "test/models/user_test.rb"]

    Open3.popen3(env, *cmd, chdir: Rails.root.to_s) do |_stdin, stdout, stderr, wait_thr|
      begin
        Timeout.timeout(30) do
          wait_thr.value # Wait for process to complete
        end
      rescue Timeout::Error
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue
          nil
        end

        flunk "Test process timed out"
      end

      stdout_output = stdout.read
      stderr.read

      # Check that stdout doesn't contain JSON logs
      json_lines_in_stdout = stdout_output.lines.select { |line|
        line.strip.start_with?("{") && begin
          JSON.parse(line)
        rescue
          nil
        end
      }

      assert_equal 0,
        json_lines_in_stdout.length,
        "Expected no JSON logs in stdout, but found #{json_lines_in_stdout.length} lines. First few:\n#{json_lines_in_stdout.first(3).join}"

      # Check that log/test.log contains JSON logs
      assert_path_exists log_file, "Expected log/test.log to exist"
      log_contents = File.read(log_file)

      json_lines_in_file = log_contents.lines.select { |line|
        line.strip.start_with?("{") && begin
          JSON.parse(line)
        rescue
          nil
        end
      }

      assert_operator json_lines_in_file.length, :>, 0, "Expected JSON logs in log/test.log, but found none. File size: #{log_contents.bytesize} bytes"

      # Verify at least one structured log exists
      parsed_logs = json_lines_in_file.map { |line| JSON.parse(line) }

      assert parsed_logs.any? { |log| log["src"] && log["evt"] && log["lvl"] },
        "Expected at least one properly structured log in log/test.log"
    end
  ensure
    # Clean up
    FileUtils.rm_f(log_file) if log_file
  end
end
