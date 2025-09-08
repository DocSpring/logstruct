# typed: true

require "test_helper"

class DotenvIntegrationTest < ActiveSupport::TestCase
  def setup
    @io = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @io, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_emits_structured_dotenv_logs_and_suppresses_unstructured_messages
    # Simulate a dotenv update event after boot
    diff = Struct.new(:env).new({"BOOT_FLAG" => "1", "REGION" => "ap-southeast-2"})
    ActiveSupport::Notifications.instrument("update.dotenv", diff: diff) {}

    ::SemanticLogger.flush

    @io.rewind
    lines = @io.read.to_s.split("\n").map(&:strip).reject(&:empty?)

    refute_empty lines, "Expected logs to be captured during test"

    json_logs = lines.filter_map { |l|
      begin
        JSON.parse(l)
      rescue
        nil
      end
    }
    dotenv_updates = json_logs.select { |h| h["src"] == "dotenv" && h["evt"] == "update" }

    refute_empty dotenv_updates, "Expected a structured dotenv update log"

    # Vars should include at least BOOT_FLAG
    assert dotenv_updates.any? { |h| Array(h["vars"]).include?("BOOT_FLAG") }, "Expected BOOT_FLAG in vars"

    # Ensure no plain unstructured "Set ..." messages slipped through
    no_unstructured = json_logs.none? { |h| h["msg"].is_a?(String) && h["msg"].start_with?("Set ") }

    assert no_unstructured, "Found unstructured 'Set ...' message in logs"
  end
end
