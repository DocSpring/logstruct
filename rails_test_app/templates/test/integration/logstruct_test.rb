# typed: true

require "test_helper"

class LogstructTest < ActionDispatch::IntegrationTest
  setup do
    # Clear any existing log records before each test
    @log_output = StringIO.new
    @original_logger = Rails.logger
    @log_device = Rails.logger.instance_variable_get(:@logdev)
    @original_log_device = @log_device.dev
    @log_device.instance_variable_set(:@dev, @log_output)
  end

  teardown do
    # Restore original logger
    @log_device.instance_variable_set(:@dev, @original_log_device)
  end

  test "basic logging produces structured JSON logs" do
    get "/logging/basic"

    assert_response :success

    # Parse the logs to verify structured format
    log_entries = parse_log_entries

    # Check that we have at least 3 log entries (info, warn, debug)
    assert_operator log_entries.length, :>=, 3, "Should have at least 3 log entries"

    # Find the structured log entry
    structured_entry = log_entries.find { |entry| entry["msg"] == "Structured log message" }

    assert structured_entry, "Should have a structured log entry"
    assert_equal "app", structured_entry["src"], "Should have correct source"
    assert_equal "info", structured_entry["lvl"], "Should have correct level"

    # Check that emails are scrubbed
    email_log = log_entries.find { |entry| entry["msg"]&.include?("email") }
    if email_log && email_log["msg"].is_a?(String)
      assert_not_includes email_log["msg"], "test@example.com", "Email should be scrubbed"
      assert_includes email_log["msg"], "[EMAIL]", "Email should be replaced with [EMAIL]"
    end
  end

  test "error logging produces structured error logs" do
    get "/logging/error"

    assert_response :success

    # Parse the logs to verify structured format
    log_entries = parse_log_entries

    # Find the exception log entries
    exception_entries = log_entries.select { |entry| entry["evt"] == "exception" }

    assert_operator exception_entries.length, :>=, 1, "Should have at least one exception log entry"

    # Check the structured exception log
    exception_entry = exception_entries.find { |entry| entry["message"] == "Structured error log" }

    assert exception_entry, "Should have a structured exception log"
    assert_equal "StandardError", exception_entry["err_class"], "Should have correct error class"
    assert_equal "app", exception_entry["src"], "Should have correct source"
  end

  test "model logging works correctly" do
    get "/logging/model"

    assert_response :success

    # Parse the logs to verify structured format
    log_entries = parse_log_entries

    # Check model log entries
    assert log_entries.any? { |entry| entry["msg"]&.include?("Created user") },
      "Should have a log entry for user creation"

    # Check the response
    response_json = JSON.parse(response.body)

    assert response_json["user_id"], "Response should include user_id"
  end

  test "job logging works correctly" do
    # Capture logs during job enqueue and execution
    get "/logging/job"

    assert_response :success

    # Parse the logs to verify job enqueue log
    log_entries = parse_log_entries

    # Check that the job was enqueued
    assert log_entries.any? { |entry| entry["msg"]&.include?("Job enqueued") },
      "Should have a log entry for job enqueue"

    # For job execution, we'd need to run the job synchronously or wait for it
    # in a real setup. For this test, we'll just check the response.
    response_json = JSON.parse(response.body)

    assert response_json["job_id"], "Response should include job_id"
  end

  test "structured logging works correctly" do
    get "/logging/structured"

    assert_response :success

    # Parse the logs to verify structured format
    log_entries = parse_log_entries

    # Check for HTTP log entry
    http_entry = log_entries.find { |entry| entry["evt"] == "http_request" }

    assert http_entry, "Should have an HTTP request log entry"
    assert_equal "GET", http_entry["method"], "Should have correct HTTP method"
    assert_equal "/logging/structured", http_entry["path"], "Should have correct path"
    assert_equal 200, http_entry["status"], "Should have correct status"

    # Check for structured exception log
    exception_entry = log_entries.find { |entry|
      entry["evt"] == "exception" && entry["message"] == "Structured exception log example"
    }

    assert exception_entry, "Should have a structured exception log example"
    assert_equal "RuntimeError", exception_entry["err_class"], "Should have correct error class"
  end

  test "context and tagging works correctly" do
    get "/logging/context"

    assert_response :success

    # Parse the logs to verify structured format
    log_entries = parse_log_entries

    # Check for tags in log entries
    tagged_entries = log_entries.select { |entry| entry["tags"] }

    assert_predicate tagged_entries, :any?, "Should have at least one tagged log entry"

    # Find entry with specific tags
    entry_with_all_tags = tagged_entries.find { |entry|
      entry["tags"]&.include?("REQUEST_ID_123") &&
        entry["tags"].include?("USER_456")
    }

    assert entry_with_all_tags, "Should have a log entry with all specified tags"

    # Find entry with nested tags
    nested_entry = tagged_entries.find { |entry|
      entry["tags"]&.include?("NESTED")
    }

    assert nested_entry, "Should have a log entry with nested tag"
    assert_equal "warn", nested_entry["lvl"], "Nested tagged message should be a warning"
  end

  private

  def parse_log_entries
    log_lines = @log_output.string.split("\n")
    log_lines.filter_map do |line|
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
  end
end
