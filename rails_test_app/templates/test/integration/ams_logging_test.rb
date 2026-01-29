# typed: true
# frozen_string_literal: true

require "test_helper"

# Test that ActiveModelSerializers logs are properly formatted as JSON,
# NOT as Ruby hash inspect with tag prefixes like:
#   [active_model_serializers] {message: "Rendered ...", tags: ["active_model_serializers"]}
class AmsLoggingTest < ActionDispatch::IntegrationTest
  def setup
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  # This test reproduces the production bug where AMS logs look like:
  # [active_model_serializers] {message: "Rendered SubmissionSerializer...", tags: ["active_model_serializers"]}
  def test_ams_logs_are_not_ruby_hash_inspect_format
    raise "AMS not available" unless defined?(::ActiveModelSerializers)

    # Trigger an AMS serialization by rendering a serialized response
    # (Need to add an endpoint that uses AMS)
    get "/logging/basic"

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Capture stdout too since AMS might log there
    stdout_output = ""
    original_stdout = $stdout
    begin
      stdout_capture = StringIO.new
      $stdout = stdout_capture

      get "/logging/basic"

      ::SemanticLogger.flush
      $stdout = original_stdout
      stdout_capture.rewind
      stdout_output = stdout_capture.read.to_s
    ensure
      $stdout = original_stdout
    end

    combined_output = output + stdout_output

    # MUST NOT have the broken [tag] {message: ...} format
    refute_match(/\[active_model_serializers\]\s*\{message:/,
      combined_output,
      "AMS logs must NOT be in broken [tag] {message: ...} format")

    # MUST NOT have Ruby hash inspect format
    refute_match(/\{message:\s*"Rendered/,
      combined_output,
      "AMS logs must NOT use Ruby hash inspect format")
  end

  def test_ams_logs_do_not_pollute_with_default_format
    raise "AMS not available" unless defined?(::ActiveModelSerializers)

    # Capture both SemanticLogger output and stdout
    original_stdout = $stdout
    stdout_capture = StringIO.new
    $stdout = stdout_capture

    get "/logging/basic"

    ::SemanticLogger.flush
    $stdout = original_stdout
    stdout_capture.rewind
    stdout_output = stdout_capture.read.to_s

    # AMS default logs like "Rendered X with Y (Zms)" should NOT appear in stdout
    refute_match(/Rendered\s+\S+Serializer\s+with/,
      stdout_output,
      "AMS default log format should not appear in stdout")
  end

  def test_ams_logs_adapter_class_name_not_serialized_output
    raise "AMS not available" unless defined?(::ActiveModelSerializers)

    get "/logging/ams"

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s

    # Find the AMS log line
    ams_lines = output.lines.select { |line| line.include?('"msg":"ams.render"') }

    assert_predicate ams_lines, :any?, "Expected to find ams.render log line, got:\n#{output}"

    ams_line = ams_lines.first
    parsed = JSON.parse(ams_line)

    # serializer should be the class name
    assert_equal "UserSerializer",
      parsed["serializer"],
      "Expected serializer to be 'UserSerializer', got: #{parsed["serializer"]}"

    # adapter should be the adapter CLASS NAME, not serialized output
    adapter = parsed["adapter"]

    assert_kind_of String, adapter, "adapter should be a string"
    assert_match(/^ActiveModelSerializers::Adapter::/,
      adapter,
      "adapter should be an AMS adapter class name like 'ActiveModelSerializers::Adapter::Attributes', got: #{adapter.inspect}")

    # MUST NOT contain serialized user data (the bug we're fixing)
    refute_includes adapter,
      "AMS Test User",
      "adapter field MUST NOT contain serialized output"
  end
end
