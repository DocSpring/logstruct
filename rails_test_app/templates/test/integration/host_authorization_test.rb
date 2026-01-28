# typed: true
# frozen_string_literal: true

require "test_helper"

class HostAuthorizationTest < ActionDispatch::IntegrationTest
  def setup
    # Capture JSON output via a dedicated SemanticLogger appender
    @io = StringIO.new
    ::SemanticLogger.clear_appenders!
    # Use synchronous appender to avoid timing issues in tests
    ::SemanticLogger.add_appender(io: @io, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_blocked_host_is_logged_with_logstruct
    # Make a request with a blocked host
    host! "blocked-host.example.com"
    get "/health"

    # Should return 403 Forbidden
    assert_response :forbidden

    blocked_host_logs = blocked_host_logs_from_output

    assert_equal 1, blocked_host_logs.size, "Expected exactly one blocked host log entry"

    log_entry = blocked_host_logs.first

    # Verify the log entry has the correct structure
    assert_equal "security", log_entry["src"]
    assert_equal "blocked_host", log_entry["evt"]
    assert_equal "blocked-host.example.com", log_entry["blocked_host"]
    assert_equal "/health", log_entry["path"]
    assert_equal "GET", log_entry["method"]
  end

  def test_allowed_host_is_not_blocked
    # Make a request with an allowed host (.localhost is allowed by default)
    host! "www.localhost"
    get "/health"

    # Should return 200 OK
    assert_response :success

    blocked_host_logs = blocked_host_logs_from_output

    assert_equal 0, blocked_host_logs.size, "Should not log blocked host for allowed hosts"
  end

  def test_blocked_host_log_can_be_serialized
    host! "malicious.example.com"
    get "/health"

    assert_response :forbidden

    blocked_host_logs = blocked_host_logs_from_output

    assert_equal 1, blocked_host_logs.size

    log_entry = blocked_host_logs.first

    # Verify it's a properly serialized hash
    assert_kind_of Hash, log_entry

    # Verify key fields are in serialized output
    assert_equal "security", log_entry["src"]
    assert_equal "blocked_host", log_entry["evt"]
    assert_equal "malicious.example.com", log_entry["blocked_host"]
    assert_equal "/health", log_entry["path"]
    assert_equal "GET", log_entry["method"]
  end

  private

  def parsed_logs_from_output
    ::SemanticLogger.flush

    @io.rewind
    lines = @io.read.to_s.split("\n").map(&:strip).reject(&:empty?)
    lines.filter_map do |line|
      JSON.parse(line)
    rescue
      nil
    end
  end

  def blocked_host_logs_from_output
    parsed_logs_from_output.select { |log| log["evt"] == "blocked_host" }
  end
end
