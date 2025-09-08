# typed: true

require "test_helper"
require "open3"

class BootLogsIntegrationTest < ActiveSupport::TestCase
  def test_rails_runner_emits_dotenv_structured_logs_and_ends_with_true
    env = {
      "LOGSTRUCT_ENABLED" => "true",
      "RAILS_ENV" => "test",
      "RAILS_LOG_TO_STDOUT" => "1"
    }
    cmd = ["bundle", "exec", "rails", "runner", "puts LogStruct.enabled?"]

    stdout_str, stderr_str, status = Open3.capture3(env, *cmd)

    assert_predicate status, :success?, "rails runner failed: #{stderr_str}"
    output = stdout_str.to_s

    refute_empty output, "Expected some output from rails runner"

    lines = output.split("\n").map(&:strip).reject(&:empty?)
    # Ensure the last non-empty line is 'true'
    last_line = lines.last

    assert_equal "true", last_line, "Expected final line to be 'true'"

    before = lines[0...-1] || []

    refute_empty before, "Expected logs before the final result"

    json_logs = before.filter_map { |l|
      begin
        JSON.parse(l)
      rescue
        nil
      end
    }
    dotenv_logs = json_logs.select { |h| h["src"] == "dotenv" }

    assert_equal 2, dotenv_logs.size, "Expected two dotenv logs"
    assert dotenv_logs.any? { |h| h["evt"] == "load" }, "Expected a load event"
    assert dotenv_logs.any? { |h| h["evt"] == "update" }, "Expected an update event"
  end

  def test_rails_runner_emits_original_dotenv_logs_when_disabled
    env = {
      "LOGSTRUCT_ENABLED" => "false",
      "RAILS_ENV" => "development",
      "RAILS_LOG_TO_STDOUT" => "1"
    }
    cmd = ["bundle", "exec", "rails", "runner", "puts LogStruct.enabled?"]

    stdout_str, stderr_str, status = Open3.capture3(env, *cmd)

    assert_predicate status, :success?, "rails runner failed: #{stderr_str}"
    output = stdout_str.to_s

    refute_empty output, "Expected some output from rails runner"

    lines = output.split("\n").map(&:strip).reject(&:empty?)
    last_line = lines.last

    assert_equal "false", last_line, "Expected final line to be 'false'"

    before = lines[0...-1] || []

    refute_empty before, "Expected logs before the final result"

    # Expect original dotenv log lines (not JSON)
    dotenv_lines = before.select { |l| l.start_with?("[dotenv]") }

    assert_equal 2, dotenv_lines.size, "Expected two original dotenv lines"
    assert dotenv_lines.any? { |l| l.include?("Set ") }, "Expected a 'Set ...' line"
    assert dotenv_lines.any? { |l| l.include?("Loaded ") }, "Expected a 'Loaded ...' line"
  end
end
