# typed: true
# frozen_string_literal: true

require "test_helper"

class ShrineLoggingTest < ActionDispatch::IntegrationTest
  def setup
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_shrine_upload_via_http_request_outputs_valid_json
    # Make a real HTTP request that triggers a Shrine upload
    get "/logging/shrine_upload"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Find Shrine log lines
    shrine_lines = output.lines.select { |line| line.include?('"src":"shrine"') }

    # Shrine upload involves multiple events: metadata, cache upload, open, store upload
    # We expect at least one upload event
    assert_operator shrine_lines.size, :>=, 1, "Expected at least 1 Shrine log line, got #{shrine_lines.size}"

    # Find the store upload line (the final upload to permanent storage)
    store_upload_line = shrine_lines.find { |line| line.include?('"evt":"upload"') && line.include?('"storage":"store"') }

    assert store_upload_line, "Expected a store upload log line"

    # MUST be valid JSON
    parsed = JSON.parse(store_upload_line)

    assert parsed, "Shrine log line must be valid JSON"

    # MUST NOT be Ruby hash inspect format
    refute_includes store_upload_line,
      "{message:",
      "Log must NOT be Ruby hash inspect format like {message: ...}"

    # MUST have proper LogStruct fields
    assert_equal "shrine", parsed["src"], "Source must be 'shrine'"
    assert_equal "upload", parsed["evt"], "Event must be 'upload'"
    assert_equal "store", parsed["storage"], "Storage must be 'store'"
    assert parsed.key?("location"), "Must have 'location' field"
    assert parsed.key?("duration_ms"), "Must have 'duration_ms' field for duration"
  end

  def test_shrine_log_not_wrapped_in_message_key
    get "/logging/shrine_upload"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    shrine_lines = output.lines.select { |line| line.include?("shrine") }

    shrine_lines.each do |line|
      # Skip non-JSON lines
      next unless line.start_with?("{")

      parsed = JSON.parse(line)

      # MUST NOT have the broken {message: "#<LogStruct...>"} wrapper
      if parsed.key?("message")
        refute_includes parsed["message"].to_s,
          "#<LogStruct",
          "Shrine struct MUST NOT be wrapped as message with inspect string"
      end

      # If this is a Shrine log, verify it's properly structured
      if parsed["src"] == "shrine"
        refute parsed.key?("message"),
          "Shrine logs should NOT have a 'message' key - fields should be at root level"
      end
    end
  end

  def test_no_duplicate_shrine_logs_per_event
    # This test specifically checks that we don't get BOTH the default Shrine log format
    # AND the LogStruct format when an app has Shrine.plugin :instrumentation already configured

    get "/logging/shrine_upload"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Find all store upload events (final upload to permanent storage)
    store_upload_lines = output.lines.select do |line|
      line.include?('"evt":"upload"') && line.include?('"storage":"store"')
    end

    # Should have exactly ONE store upload log (not duplicated by Shrine's default + LogStruct)
    assert_equal 1,
      store_upload_lines.size,
      "Expected exactly 1 store upload log line, got #{store_upload_lines.size}:\n#{store_upload_lines.join}"

    # The log must be in LogStruct JSON format, NOT Shrine's default format
    store_upload_line = store_upload_lines.first

    assert store_upload_line.start_with?("{"), "Log must be JSON format, not Shrine default format"

    parsed = JSON.parse(store_upload_line)

    assert_equal "shrine", parsed["src"], "Log must have LogStruct 'src' field"
  end

  def test_shrine_logs_are_json_not_ruby_inspect
    get "/logging/shrine_upload"

    assert_response :success

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # No line should contain Ruby object inspect format
    output.lines.each do |line|
      refute_includes line,
        "#<LogStruct::Log::Shrine",
        "No log line should contain Ruby inspect format for LogStruct structs"
      refute_includes line,
        "#<Shrine",
        "No log line should contain Ruby inspect format for Shrine objects"
    end
  end

  def test_shrine_default_log_format_is_suppressed
    # Capture STDOUT to check for Shrine's default log format
    # Shrine's default format looks like: "Upload (0ms) – {storage: :store, ...}"
    original_stdout = $stdout
    stdout_capture = StringIO.new
    $stdout = stdout_capture

    get "/logging/shrine_upload"

    assert_response :success

    ::SemanticLogger.flush
    $stdout = original_stdout
    stdout_capture.rewind
    stdout_output = stdout_capture.read.to_s

    # Shrine's default log format should NOT appear
    refute_match(/Upload \(\d+ms\) – \{/,
      stdout_output,
      "Shrine's default log format should not appear in stdout")
    refute_match(/Metadata \(\d+ms\) – \{/,
      stdout_output,
      "Shrine's default metadata format should not appear in stdout")
    refute_match(/Open \(\d+ms\) – \{/,
      stdout_output,
      "Shrine's default open format should not appear in stdout")
  end
end
