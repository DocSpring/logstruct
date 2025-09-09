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
    assert_includes content, "export enum Level", "Should export Level enum"
    assert_includes content, "export enum Source", "Should export Source enum"
    assert_includes content, "export enum Event", "Should export Event enum"
    assert_includes content, "export enum LogType", "Should export LogType enum"

    # Test that it includes log type interfaces
    assert_includes content, "export interface RequestLog", "Should export RequestLog interface"
    assert_includes content, "export interface ErrorLog", "Should export ErrorLog interface"

    # Test that backtrace is an array of strings in the ErrorLog
    assert_includes content, "backtrace: string[];", "ErrorLog should have backtrace as string array"

    # Test that it includes the union type
    assert_includes content, "export type Log =", "Should export Log union type"

    # Check if the enums JSON file was created
    enums_json_file = File.join(File.dirname(@output_ts_file), "sorbet-enums.json")

    assert_path_exists enums_json_file, "Enums JSON file should have been created"

    # Check if the log structs JSON file was created
    structs_json_file = File.join(File.dirname(@output_ts_file), "sorbet-log-structs.json")

    assert_path_exists structs_json_file, "Log structs JSON file should have been created"
  end

  def test_generate_typescript_definitions
    # Test that we can generate TypeScript definitions without writing to a file
    content = @exporter.generate_typescript_definitions

    # Verify basic structure
    assert_kind_of String, content
    assert_includes content, "export enum Level"
    assert_includes content, "export enum LogType"
  end

  def test_export_enums_includes_all_enum_classes
    # Test that all expected enums are exported
    enums = @exporter.send(:export_enums)

    # Check Level is included
    assert enums.key?(:Level), "Level enum should be included"
    assert_includes enums[:Level], :info, "Level should include :info"

    # Check Source is included
    assert enums.key?(:Source), "Source enum should be included"
    assert_includes enums[:Source], :rails, "Source should include :rails"

    # Check Event is included
    assert enums.key?(:Event), "Event enum should be included"
    assert_includes enums[:Event], :log, "Event should include :log"
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

  def test_level_is_enum_type
    # Test with the actual Level enum field from a log class
    request_struct = LogStruct::Log::Request
    level_prop_info = request_struct.props[:level]

    # Extract type info
    type_info = @exporter.extract_type_info(level_prop_info)

    # Test that it's correctly identified as an enum
    assert_equal "enum", type_info[:type], "Level should be identified as an enum type"
    assert_equal "Level", type_info[:values], "Level enum name should be preserved"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "Level", ts_type, "Level TypeScript type should match the enum name"
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
    # Use exporter aggregated data instead of parent class props
    logs = @exporter.send(:export_log_structs)
    storage = logs["ActiveStorage"]

    refute_nil storage, "ActiveStorage group should be present"
    type_info = storage[:fields][:metadata]

    assert_equal "object", type_info[:type], "Metadata should be identified as an object type"

    # Verify in the generated TypeScript file
    content = @exporter.generate_typescript_definitions

    assert_includes content, "metadata?: Record<string, any>;", "ActiveStorageLog should have metadata as optional Record<string, any>"
  end

  def test_security_event_union_type
    # Use exporter aggregated data to verify union of security events
    logs = @exporter.send(:export_log_structs)
    security = logs["Security"]

    refute_nil security, "Security group should be present"
    type_info = security[:fields][:event]

    # Test that it's correctly identified as an enum union type
    assert_equal "enum_union", type_info[:type], "Security event should be identified as an enum_union type"
    assert_equal "Event", type_info[:base_enum], "Security event should use Event as base enum"

    # Verify we extracted the correct enum values - sort both arrays to avoid order issues
    expected_values = ["IPSpoof", "CSRFViolation", "BlockedHost"].sort
    extracted_values = type_info[:enum_values].sort

    assert_equal expected_values, extracted_values, "Should extract the correct enum values"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    # Order doesn't matter for union types, but we need to ensure all parts are present
    # These should match how the enum values are declared in the TypeScript output
    ["Event.IP_SPOOF", "Event.CSRF_VIOLATION", "Event.BLOCKED_HOST"].each do |part|
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
    ["Event.IP_SPOOF", "Event.CSRF_VIOLATION", "Event.BLOCKED_HOST", "|"].each do |part|
      assert_includes event_line, part, "event field should include #{part} in its type"
    end
  end

  def test_single_enum_value_restriction
    # Use exporter aggregated data to verify specific Source value for ActiveJob
    logs = @exporter.send(:export_log_structs)
    active_job = logs["ActiveJob"]

    refute_nil active_job, "ActiveJob group should be present"
    type_info = active_job[:fields][:source]

    # Test that it's correctly identified as an enum_single type
    assert_equal "enum_single", type_info[:type], "Should be identified as a single enum value restriction"
    assert_equal "Source", type_info[:base_enum], "Should use Source as base enum"
    assert_equal "Job", type_info[:enum_value], "Should extract the specific enum value 'Job'"

    # Test the resulting TypeScript type
    ts_type = @exporter.typescript_type_for(type_info)

    assert_equal "Source.JOB", ts_type, "TypeScript type should be the specific enum value"

    # Now check that the full TypeScript generation includes this restricted type
    content = @exporter.generate_typescript_definitions

    # Find the ActiveJobLog interface section
    job_log_section = content.match(/export interface ActiveJobLog \{.*?\}/m)

    assert job_log_section, "Should find ActiveJobLog interface in the generated TypeScript"

    # Extract the source line and check if it has the specific enum value
    source_line = job_log_section[0].lines.find { |line| line.strip.start_with?("source:") }

    assert source_line, "ActiveJobLog interface should have a source field"

    # The source field should be a specific enum value, not a generic Source enum
    assert_equal "source: Source.JOB;",
      source_line.strip,
      "source field should be Source.JOB specifically, not just Source"
    refute_includes source_line, "Source;", "source field should not be the general Source enum"
  end

  def test_exports_event_type_arrays
    # Test that we export valid event type arrays for each log type
    content = @exporter.generate_typescript_definitions

    # Check Security log events array
    security_array_match = content.match(/export const SecurityEvents: Array<(.*?)> = \[(.*?)\]/m)

    assert security_array_match, "Should export a SecurityEvents array"

    # Check the union type for the array
    security_type = security_array_match[1]

    ["Event.BLOCKED_HOST", "Event.CSRF_VIOLATION", "Event.IP_SPOOF"].each do |event|
      assert_includes security_type, event, "SecurityEvents type should contain #{event}"
    end

    # Check the array content
    security_array_content = security_array_match[2]

    ["Event.BLOCKED_HOST", "Event.CSRF_VIOLATION", "Event.IP_SPOOF"].each do |event|
      assert_includes security_array_content, event, "SecurityEvents array should contain #{event}"
    end

    # Check ActiveJob log events array
    activejob_array_match = content.match(/export const ActiveJobEvents: Array<(.*?)> = \[(.*?)\]/m)

    assert activejob_array_match, "Should export an ActiveJobEvents array"

    # Check the array content
    activejob_array_content = activejob_array_match[2]

    ["Event.ENQUEUE", "Event.START", "Event.FINISH", "Event.SCHEDULE"].each do |event|
      assert_includes activejob_array_content, event, "ActiveJobEvents array should contain #{event}"
    end

    # Check ActiveStorage log events array
    storage_array_match = content.match(/export const ActiveStorageEvents: Array<(.*?)> = \[(.*?)\]/m)

    assert storage_array_match, "Should export an ActiveStorageEvents array"

    # Check the array content
    storage_array_content = storage_array_match[2]

    ["Event.UPLOAD", "Event.DOWNLOAD", "Event.DELETE", "Event.STREAM"].each do |event|
      assert_includes storage_array_content, event, "ActiveStorageEvents array should contain #{event}"
    end
  end

  def test_exports_all_log_types_array
    # Test that we export the array of all log types
    content = @exporter.generate_typescript_definitions

    # Check for the AllLogTypes array
    all_types_match = content.match(/export const AllLogTypes: Array<LogType> = \[(.*?)\]/m)

    assert all_types_match, "Should export an AllLogTypes array"

    # Check the array content
    all_types_content = all_types_match[1]

    # Check that all log types are included in the array
    ["LogType.SIDEKIQ", "LogType.SHRINE", "LogType.SECURITY", "LogType.REQUEST",
      "LogType.PLAIN", "LogType.ERROR", "LogType.ACTIVEJOB", "LogType.ACTIVESTORAGE",
      "LogType.ACTIONMAILER", "LogType.CARRIERWAVE"].each do |log_type|
      assert_includes all_types_content, log_type, "AllLogTypes array should contain #{log_type}"
    end
  end

  def test_exports_enums_to_json
    # Get the temp directory for output
    enums_json_file = File.join(@temp_dir, "sorbet-enums.json")

    # Get the data
    data = @exporter.send(:generate_data)

    # Export enums to JSON
    @exporter.export_enums_to_json(data[:enums], enums_json_file)

    # Verify file exists
    assert_path_exists enums_json_file, "Enums JSON file should have been created"

    # Read and parse the JSON
    json_data = JSON.parse(File.read(enums_json_file))

    # Verify structure
    assert_kind_of Hash, json_data, "JSON data should be a hash"

    # Check for specific enums
    assert json_data.key?("LogStruct::Level"), "Should include LogStruct::Level"
    assert json_data.key?("LogStruct::Source"), "Should include LogStruct::Source"
    assert json_data.key?("LogStruct::Event"), "Should include LogStruct::Event"

    # Check that values are properly structured
    level_values = json_data["LogStruct::Level"]

    assert_kind_of Array, level_values, "Values should be an array"
    assert_kind_of Hash, level_values.first, "Each value should be a hash"
    assert level_values.first.key?("name"), "Each value should have a name"
    assert level_values.first.key?("value"), "Each value should have a value"

    # Check for specific enum values
    level_values.each do |value|
      if value["name"] == "Info"
        assert_equal "info", value["value"], "Info enum should serialize as 'info'"
      end
    end
  end

  def test_exports_log_structs_to_json
    # Get the temp directory for output
    structs_json_file = File.join(@temp_dir, "sorbet-log-structs.json")

    # Get the data
    data = @exporter.send(:generate_data)

    # Export log structs to JSON
    @exporter.export_log_structs_to_json(data[:logs], structs_json_file)

    # Verify file exists
    assert_path_exists structs_json_file, "Log structs JSON file should have been created"

    # Read and parse the JSON
    json_data = JSON.parse(File.read(structs_json_file))

    # Verify structure
    assert_kind_of Hash, json_data, "JSON data should be a hash"

    # Check for specific structs
    assert json_data.key?("LogStruct::Log::Request"), "Should include LogStruct::Log::Request"
    assert json_data.key?("LogStruct::Log::Error"), "Should include LogStruct::Log::Error"
    assert json_data.key?("LogStruct::Log::Plain"), "Should include LogStruct::Log::Plain"

    # Check struct structure
    request_struct = json_data["LogStruct::Log::Request"]

    assert_equal "Request", request_struct["name"], "Should have correct name"
    assert request_struct.key?("fields"), "Should have fields"

    # Check field structure
    fields = request_struct["fields"]

    assert_kind_of Hash, fields, "Fields should be a hash"

    # Check specific fields
    assert fields.key?("path"), "Should have path field"
    assert fields.key?("status"), "Should have status field"
    assert fields.key?("duration_ms"), "Should have duration_ms field"

    # Check field types
    assert_equal "string", fields["path"]["type"], "Path should be a string"
    assert_equal "integer", fields["status"]["type"], "Status should be an integer"
    assert_equal "number", fields["duration_ms"]["type"], "Duration_ms should be a number"
  end
end
