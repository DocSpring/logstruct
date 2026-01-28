# typed: true

require "test_helper"
require "net/http"

class RequestLoggingE2eTest < ActiveSupport::TestCase
  # Test that real HTTP requests through Puma produce valid JSON request logs
  def test_real_http_request_produces_json_request_log
    port = 32125
    env = rails_server_env
    cmd = rails_server_cmd(port)

    lines, stderr_output = with_process(
      env: env,
      cmd: cmd,
      ready_timeout: 15,
      ready_matchers: ["Use Ctrl-C to stop", "Listening on"]
    ) do |out_lines, stdout, _stderr, _wait_thr|
      uri = URI("http://127.0.0.1:#{port}/logging/basic")
      response = Net::HTTP.get_response(uri)

      assert_equal "200", response.code, "Request should succeed"

      sleep 0.5
      drain_nonblocking(stdout, out_lines)
    end

    output = lines.join("\n")

    json_lines = lines.filter_map do |l|
      JSON.parse(l) if l.strip.start_with?("{")
    rescue JSON::ParserError
      nil
    end

    request_logs = json_lines.select { |h| h["evt"] == "request" }

    assert_predicate request_logs,
      :any?,
      "Expected at least one request log.\nJSON logs: #{json_lines.map(&:inspect).join("\n")}\nAll output: #{output}\nSTDERR: #{stderr_output}"

    request_log = request_logs.first

    assert_equal "rails", request_log["src"], "Source must be 'rails'"
    assert_equal "request", request_log["evt"], "Event must be 'request'"
    assert request_log.key?("path"), "Must have 'path' field"
    assert request_log.key?("status"), "Must have 'status' field"
    assert request_log.key?("duration_ms"), "Must have 'duration_ms' field"

    request_line = lines.find { |l| l.include?('"evt":"request"') }

    assert request_line, "Should find request log line"
    refute_match(/\{message:/, request_line, "Request log must NOT be Ruby hash inspect format")
    refute_match(/\{:message=>/, request_line, "Request log must NOT be Ruby hash rocket format")
  end

  # Test that AMS-style tagged logging doesn't produce broken format
  def test_tagged_logging_does_not_produce_ruby_hash_format
    port = 32126
    env = rails_server_env
    cmd = rails_server_cmd(port)

    lines, _stderr_output = with_process(
      env: env,
      cmd: cmd,
      ready_timeout: 15,
      ready_matchers: ["Use Ctrl-C to stop", "Listening on"]
    ) do |out_lines, stdout, _stderr, _wait_thr|
      uri = URI("http://127.0.0.1:#{port}/logging/basic")
      Net::HTTP.get_response(uri)

      sleep 0.5
      drain_nonblocking(stdout, out_lines)
    end

    lines.each do |line|
      refute_match(
        /\[[\w_]+\]\s*\{message:/,
        line,
        "No log line should have broken [tag] {message: ...} format. Line: #{line}"
      )
      refute_match(
        /\{message:.*tags:/,
        line,
        "No log line should have {message: ..., tags: ...} Ruby format. Line: #{line}"
      )
    end

    json_lines = lines.select { |l| l.strip.start_with?("{") }
    json_lines.each do |line|
      parsed = JSON.parse(line)

      assert parsed, "Line should be valid JSON: #{line}"
    rescue JSON::ParserError => e
      flunk "Line should be valid JSON but got parse error: #{e.message}\nLine: #{line}"
    end
  end
end
