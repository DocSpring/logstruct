# typed: true

require "test_helper"

class LogrageFormatterIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # Capture JSON output via a dedicated SemanticLogger appender
    @io = StringIO.new
    ::SemanticLogger.clear_appenders!
    # Use synchronous appender to avoid timing issues in tests
    ::SemanticLogger.add_appender(io: @io, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_request_through_stack_emits_json_request_log
    get "/logging/basic", params: {format: :json}

    assert_response :success

    # Ensure all logs are flushed from buffers
    ::SemanticLogger.flush

    # Read all logged lines
    @io.rewind
    lines = @io.read.to_s.split("\n").map(&:strip).reject(&:empty?)

    refute_empty lines, "Expected some JSON logs to be emitted"

    # Find the request log entry
    request_log = lines.filter_map { |l|
      begin
        JSON.parse(l)
      rescue
        nil
      end
    }.find { |h| h["evt"] == "request" }

    refute_nil request_log, "Expected a request log entry"

    # Validate normalized types
    assert_equal "GET", request_log["method"]
    assert_equal "json", request_log["format"]
    assert_kind_of Hash, request_log["params"]
  end
end
