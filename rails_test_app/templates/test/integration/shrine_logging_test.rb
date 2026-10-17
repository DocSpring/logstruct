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

  def test_an_upload_line_leaves_out_the_original_filename
    io = StringIO.new("hello")
    io.define_singleton_method(:original_filename) { "Jane Doe lease.pdf" }

    uploaded = DocumentUploader.upload(io, :store)
    ::SemanticLogger.flush

    assert_equal "Jane Doe lease.pdf", uploaded.original_filename
    upload = @log_output.string.lines.map { |line| JSON.parse(line) }.find { |line| line["src"] == "shrine" && line["evt"] == "upload" }

    assert_equal ["store", 5], upload&.values_at("storage", "size")
    assert_not_includes @log_output.string, "Jane Doe"
  end

  def test_each_shrine_operation_logs_what_shrine_reports
    uploaded = DocumentUploader.upload(StringIO.new("hello"), :store)
    uploaded.exists?
    uploaded.download.close!
    uploaded.delete
    ::SemanticLogger.flush

    lines = @log_output.string.lines.map { |line| JSON.parse(line) }.select { |line| line["src"] == "shrine" }
    by_event = lines.group_by { |line| line["evt"] }

    upload = by_event.fetch("upload").last

    assert_equal ["store", uploaded.id, 5], upload.values_at("storage", "location", "size")
    assert_not upload.key?("filename")
    # Shrine's metadata event has the storage and the time it took, not the metadata it extracted
    metadata = by_event.fetch("metadata").last

    assert_equal "store", metadata["storage"]
    assert_kind_of Float, metadata["duration_ms"]
    assert_empty metadata.keys & ["metadata", "location"]
    # Nor does its exists event have the answer
    exists = by_event.fetch("exist").last

    assert_equal uploaded.id, exists["location"]
    assert_not exists.key?("exist")
    assert_equal [uploaded.id], by_event.fetch("download").map { |line| line["location"] }
    assert_equal [uploaded.id], by_event.fetch("delete").map { |line| line["location"] }
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

  def test_shrine_default_log_subscriber_does_not_log_events
    # config/initializers/shrine.rb loads the instrumentation plugin with Shrine's default
    # log subscriber, which writes lines like "Upload (0ms) – {storage: :store, ...}"
    shrine_log = StringIO.new
    original_logger = Shrine.logger
    Shrine.logger = Logger.new(shrine_log)

    get "/logging/shrine_upload"

    assert_response :success
    refute_match(/(Upload|Metadata|Open|Download|Exists|Delete) \(\d+ms\) –/, shrine_log.string)
  ensure
    Shrine.logger = original_logger
  end

  def test_shrine_logger_writes_json
    Shrine.warn("test warning")

    ::SemanticLogger.flush
    line = @log_output.string.lines.find { |l| l.include?("test warning") }

    assert line, "Expected the Shrine warning in the LogStruct output:\n#{@log_output.string}"
    assert_equal "SHRINE WARNING: test warning", JSON.parse(line)["msg"]
  end
end
