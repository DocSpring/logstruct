# typed: true
# frozen_string_literal: true

require "test_helper"
require_relative "../../tools/log_types_exporter"
require "tempfile"

class LogStructLogTypesExporterTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @output_ts_file = File.join(@temp_dir, "log-types.ts")
    @exporter = LogStruct::Tools::LogTypesExporter.new(@output_ts_file)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_generates_typescript_types
    @exporter.export

    # Verify file exists
    assert_path_exists @output_ts_file, "TypeScript file should have been created"

    # Read the content
    content = File.read(@output_ts_file)

    # Test that TS content has necessary components
    assert_includes content, "export enum LogLevel", "Should export LogLevel enum"
    assert_includes content, "export enum Source", "Should export Source enum"
    assert_includes content, "export enum LogEvent", "Should export LogEvent enum"
    assert_includes content, "export enum LogType", "Should export LogType enum"

    # Test that it includes log type interfaces
    assert_includes content, "export interface RequestLog", "Should export RequestLog interface"
    assert_includes content, "export interface ErrorLog", "Should export ErrorLog interface"

    # Test that backtrace is an array of strings in the ErrorLog
    assert_includes content, "backtrace: string[];", "ErrorLog should have backtrace as string array"

    # Test that it includes the union type
    assert_includes content, "export type Log =", "Should export Log union type"
  end

  def test_generate_typescript_definitions
    # Test that we can generate TypeScript definitions without writing to a file
    content = @exporter.generate_typescript_definitions

    # Verify basic structure
    assert_kind_of String, content
    assert_includes content, "export enum LogLevel"
    assert_includes content, "export enum LogType"
  end

  def test_export_enums_includes_all_enum_classes
    # Test that all expected enums are exported
    enums = @exporter.send(:export_enums)

    # Check LogLevel is included
    assert enums.key?(:LogLevel), "LogLevel enum should be included"
    assert_includes enums[:LogLevel], :info, "LogLevel should include :info"

    # Check Source is included
    assert enums.key?(:Source), "Source enum should be included"
    assert_includes enums[:Source], :request, "Source should include :request"

    # Check LogEvent is included
    assert enums.key?(:LogEvent), "LogEvent enum should be included"
    assert_includes enums[:LogEvent], :log, "LogEvent should include :log"
  end

  def test_error_log_backtrace_is_string_array
    # Get the actual Error log struct class
    error_struct = LogStruct::Log::Error

    # Get the backtrace prop info
    backtrace_prop_info = error_struct.props[:backtrace]

    # Extract the type info using our exporter
    type_info = @exporter.extract_type_info(backtrace_prop_info)

    # Test that it's correctly identified as an array
    assert_equal "array", type_info[:type], "Backtrace should be identified as an array type"
    assert_equal "string", type_info[:item_type], "Backtrace should have string items"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "string[]", ts_type, "Backtrace TypeScript type should be string[]"
  end

  def test_plain_log_message_is_any_type
    # Get the actual Plain log struct class
    plain_struct = LogStruct::Log::Plain

    # Get the message prop info
    message_prop_info = plain_struct.props[:message]

    # Extract the type info using our exporter
    type_info = @exporter.extract_type_info(message_prop_info)

    # Test that it's correctly identified as any type
    assert_equal "any", type_info[:type], "Plain log message should be identified as any type"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "any", ts_type, "Plain log message TypeScript type should be any"
  end

  def test_log_level_is_enum_type
    # Test with the actual LogLevel enum field from a log class
    request_struct = LogStruct::Log::Request
    level_prop_info = request_struct.props[:level]

    # Extract type info
    type_info = @exporter.extract_type_info(level_prop_info)

    # Test that it's correctly identified as an enum
    assert_equal "enum", type_info[:type], "LogLevel should be identified as an enum type"
    assert_equal "LogLevel", type_info[:values], "LogLevel enum name should be preserved"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "LogLevel", ts_type, "LogLevel TypeScript type should match the enum name"
  end

  def test_timestamp_is_date_time_string
    # Test with the actual timestamp field from a log class
    log_struct = LogStruct::Log::Plain
    timestamp_prop_info = log_struct.props[:timestamp]

    # Extract type info
    type_info = @exporter.extract_type_info(timestamp_prop_info)

    # Test that it's correctly identified as a string with date-time format
    assert_equal "string", type_info[:type], "Timestamp should be identified as a string type"
    assert_equal "date-time", type_info[:format], "Timestamp should have date-time format"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "string", ts_type, "Timestamp TypeScript type should be string"
  end

  def test_active_storage_metadata_is_object_type
    # Test with the actual metadata field from ActiveStorage log class
    storage_struct = LogStruct::Log::ActiveStorage
    metadata_prop_info = storage_struct.props[:metadata]

    # Extract type info
    type_info = @exporter.extract_type_info(metadata_prop_info)

    # Test that it's correctly identified as an object type
    assert_equal "object", type_info[:type], "Metadata should be identified as an object type"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "Record<string, any>", ts_type, "Metadata TypeScript type should be Record<string, any>"

    # Verify in the generated TypeScript file
    content = @exporter.generate_typescript_definitions

    # Check for the metadata field definition in the ActiveStorageLog interface
    assert_includes content, "metadata?: Record<string, any>;", "ActiveStorageLog should have metadata as optional Record<string, any>"
  end

  def test_security_log_event_union_type
    # Get the actual Security log struct class
    security_struct = LogStruct::Log::Security
    
    # Get the event prop info
    event_prop_info = security_struct.props[:event]

    # Extract the type info using our exporter
    type_info = @exporter.extract_type_info(event_prop_info)

    # Test that it's correctly identified as an enum union type
    assert_equal "enum_union", type_info[:type], "Security event should be identified as an enum_union type"
    assert_equal "LogEvent", type_info[:base_enum], "Security event should use LogEvent as base enum"
    
    # Verify we extracted the correct enum values - sort both arrays to avoid order issues
    expected_values = ["IPSpoof", "CSRFViolation", "BlockedHost"].sort
    extracted_values = type_info[:enum_values].sort
    assert_equal expected_values, extracted_values, "Should extract the correct enum values"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)
    
    # Order doesn't matter for union types, but we need to ensure all parts are present
    # These should match how the enum values are declared in the TypeScript output
    ["LogEvent.IP_SPOOF", "LogEvent.CSRF_VIOLATION", "LogEvent.BLOCKED_HOST"].each do |part|
      assert_includes ts_type, part, "TypeScript type should include #{part}"
    end
    # Verify it's a union with pipe separators
    assert_equal 2, ts_type.count("|"), "TypeScript type should have 2 union operators"

    # Verify it appears correctly in the generated TypeScript
    content = @exporter.generate_typescript_definitions
    
    # Check that the SecurityLog interface has the event field with a union type
    # We don't check the exact string since the order may vary
    security_log_section = content.match(/export interface SecurityLog \{.*?\}/m)
    assert security_log_section, "Should find SecurityLog interface in the generated TypeScript"
    
    event_line = security_log_section[0].lines.find { |line| line.strip.start_with?("event:") }
    assert event_line, "SecurityLog interface should have an event field"
    
    # Verify that the event line contains all three enum values and union operators
    ["LogEvent.IP_SPOOF", "LogEvent.CSRF_VIOLATION", "LogEvent.BLOCKED_HOST", "|"].each do |part|
      assert_includes event_line, part, "event field should include #{part} in its type"
    end
  end
end
