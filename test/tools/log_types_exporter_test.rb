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

  def test_export_generates_json_artifacts
    @exporter.export

    dir = File.dirname(@output_ts_file)
    enums_json_file = File.join(dir, "sorbet-enums.json")
    structs_json_file = File.join(dir, "sorbet-log-structs.json")

    assert_path_exists enums_json_file, "Enums JSON file should have been created"
    assert_path_exists structs_json_file, "Log structs JSON file should have been created"

    enums = JSON.parse(File.read(enums_json_file))
    structs = JSON.parse(File.read(structs_json_file))

    assert enums.key?("LogStruct::Level"), "Level enum should be included"
    assert_kind_of Hash, structs, "Structs JSON should be a hash"
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
    logs = @exporter.export_log_structs
    storage = logs["ActiveStorage"]

    refute_nil storage, "ActiveStorage group should be present"
    type_info = storage[:fields][:metadata]

    assert_equal "object", type_info[:type], "Metadata should be identified as an object type"

    assert_equal "object", type_info[:type]
  end

  def test_security_event_union_type
    logs = @exporter.export_log_structs
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

    # Verify union presence via aggregated data only
    assert_equal "enum_union", type_info[:type]
    assert_equal "Event", type_info[:base_enum]
    assert_equal ["IPSpoof", "CSRFViolation", "BlockedHost"].sort, type_info[:enum_values].sort
  end

  def test_single_enum_value_restriction
    # Use exporter aggregated data to verify specific Source value for ActiveJob
    logs = @exporter.export_log_structs
    active_job = logs["ActiveJob"]

    refute_nil active_job, "ActiveJob group should be present"
    type_info = active_job[:fields][:source]

    # Test that it's correctly identified as an enum_single type
    assert_equal "enum_single", type_info[:type], "Should be identified as a single enum value restriction"
    assert_equal "Source", type_info[:base_enum], "Should use Source as base enum"
    assert_equal "Job", type_info[:enum_value], "Should extract the specific enum value 'Job'"

    # No TS generation; ensure enum_single info is present as expected
    assert_equal "enum_single", type_info[:type]
    assert_equal "Source", type_info[:base_enum]
    assert_equal "Job", type_info[:enum_value]
  end

  # Removed TS-array export tests: exporter is JSON-only now

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
