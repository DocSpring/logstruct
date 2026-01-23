# typed: true
# frozen_string_literal: true

require "test_helper"

class RequestLoggingTest < ActionDispatch::IntegrationTest
  def setup
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_request_produces_valid_json_request_log
    # Make a request to a controller action (proc routes don't trigger Lograge)
    get "/logging/basic"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Find request log lines (Lograge output has evt:"request")
    request_lines = output.lines.select { |line| line.include?('"evt":"request"') }

    # MUST have at least one request log
    assert_operator request_lines.size, :>=, 1, "Expected at least 1 request log line, got #{request_lines.size}. Output:\n#{output}"

    request_line = request_lines.first

    # MUST be valid JSON
    parsed = JSON.parse(request_line)

    assert parsed, "Request log must be valid JSON"

    # MUST have proper LogStruct request fields
    assert_equal "rails", parsed["src"], "Source must be 'rails'"
    assert_equal "request", parsed["evt"], "Event must be 'request'"
    assert parsed.key?("path"), "Must have 'path' field"
    assert parsed.key?("status"), "Must have 'status' field"
    assert parsed.key?("duration_ms"), "Must have 'duration_ms' field"
  end

  def test_request_log_not_ruby_hash_inspect_format
    get "/logging/basic"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # MUST NOT contain Ruby hash inspect format
    refute_match(/\{message:/,
      output,
      "Request logs must NOT be Ruby hash inspect format like {message: ...}")
    refute_match(/\{:message=>/,
      output,
      "Request logs must NOT be Ruby hash rocket format like {:message=>...}")
  end

  def test_request_log_contains_controller_and_action
    get "/logging/basic"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Find request log
    request_lines = output.lines.select { |line| line.include?('"evt":"request"') }

    assert_operator request_lines.size, :>=, 1, "Expected request log. Output:\n#{output}"

    request_line = request_lines.first
    parsed = JSON.parse(request_line)

    # Must have controller and action
    assert_equal "LoggingController", parsed["controller"], "Must have controller field"
    assert_equal "test_basic", parsed["action"], "Must have action field"
    assert_equal "/logging/basic", parsed["path"], "Must have correct path"
  end

  def test_all_logs_during_request_have_request_id
    get "/logging/basic"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Parse all JSON log lines
    json_logs = output.lines.filter_map do |line|
      JSON.parse(line) if line.strip.start_with?("{")
    rescue JSON::ParserError
      nil
    end

    assert_operator json_logs.size, :>=, 1, "Expected at least 1 JSON log line"

    # Find the request log to get the request_id
    request_log = json_logs.find { |log| log["evt"] == "request" }

    assert request_log, "Expected a request log"

    request_id = request_log["req_id"]

    assert request_id, "Request log must have req_id"

    # All logs during the request should have the same req_id
    json_logs.each do |log|
      assert_equal request_id, log["req_id"], "All logs must have req_id. Log missing it: #{log.inspect}"
    end
  end
end
