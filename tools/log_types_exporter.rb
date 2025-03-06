# typed: strict
# frozen_string_literal: true

# Load LogStruct type definitions
require_relative "../lib/log_struct"

require "json"
require "fileutils"

module LogStruct
  module Tools
    class LogTypesExporter
      extend T::Sig

      DEFAULT_OUTPUT_JSON_FILE = "site/lib/log-generation/log-types.json"
      DEFAULT_OUTPUT_TS_FILE = "site/lib/log-generation/log-types.ts"

      sig { params(output_json_file: String, output_ts_file: String).void }
      def initialize(output_json_file = DEFAULT_OUTPUT_JSON_FILE, output_ts_file = DEFAULT_OUTPUT_TS_FILE)
        @output_json_file = output_json_file
        @output_ts_file = output_ts_file
      end

      sig { void }
      def export
        # Create the exporter and run it
        puts "Exporting LogStruct types to TypeScript..."
        puts "Output file: #{@output_ts_file}"

        puts "Done! TypeScript type definitions generated at #{@output_ts_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(@output_json_file))
        FileUtils.mkdir_p(File.dirname(@output_ts_file))

        # Get the data
        log_types_data = generate_data

        # Export JSON
        export_json(log_types_data)

        # Export TypeScript types
        export_typescript(log_types_data)

        puts "Exported log types to #{@output_json_file} and #{@output_ts_file}"
      end

      private

      sig { returns(T::Hash[String, T.untyped]) }
      def generate_data
        # Export everything as a hash
        {
          # Export enum values
          enums: {
            LogLevel: LogStruct::LogLevel.values.map(&:serialize),
            Source: LogStruct::Source.values.map(&:serialize),
            LogEvent: LogStruct::LogEvent.values.map(&:serialize)
          },

          # Export log structs
          logs: export_log_structs
        }
      end

      sig { params(data: T::Hash[String, T.untyped]).void }
      def export_json(data)
        # Write to JSON file
        File.write(@output_json_file, JSON.pretty_generate(data))
      end

      sig { params(data: T::Hash[String, T.untyped]).void }
      def export_typescript(data)
        ts_content = []

        # Add file header
        ts_content << "// Auto-generated TypeScript definitions for LogStruct"
        ts_content << "// Generated on #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
        ts_content << ""

        # Add enum definitions
        ts_content << "// Enum types"
        data[:enums].each do |enum_name, enum_values|
          ts_content << "export enum #{enum_name} {"
          enum_values.each do |value|
            ts_content << "  #{value.upcase} = \"#{value}\","
          end
          ts_content << "}"
          ts_content << ""
        end

        # Add LogType enum
        ts_content << "// Log Types"
        ts_content << "export enum LogType {"
        data[:logs].keys.each do |log_type|
          ts_content << "  #{log_type.upcase} = \"#{log_type}\","
        end
        ts_content << "}"
        ts_content << ""

        # Add interface for each log type
        ts_content << "// Log Interfaces"
        data[:logs].each do |log_type, log_info|
          ts_content << "export interface #{log_type}Log {"
          log_info[:fields].each do |field_name, field_info|
            type_str = typescript_type_for(field_info)
            optional = field_info[:optional] ? "?" : ""
            ts_content << "  #{field_name}#{optional}: #{type_str};"
          end
          ts_content << "}"
          ts_content << ""
        end

        # Add union type for all logs
        ts_content << "// Union type for all logs"
        ts_content << "export type Log ="
        log_types = data[:logs].keys.map { |type| "  | #{type}Log" }
        ts_content << log_types.join("\n")
        ts_content << ";"

        # Write to TypeScript file
        File.write(@output_ts_file, ts_content.join("\n"))
      end

      sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
      def export_log_structs
        result = {}

        # Get all log structs using reflection
        T::Struct.subclasses
          .select { |klass| klass.name.to_s.start_with?("LogStruct::Log::") }
          .each do |log_class|
          # Extract class name (e.g., "Request" from "LogStruct::Log::Request")
          class_name = log_class.name.to_s.split("::").last

          # Export fields with their types
          fields = {}
          log_class.props.each do |field_name, prop_info|
            # Use http_method -> method conversion for Request
            field_key = field_name
            field_key = :method if field_name == :http_method && class_name == "Request"

            # Get type information
            type_info = extract_type_info(prop_info)

            # Add to fields
            fields[field_key] = type_info
          end

          # Add to result
          result[class_name] = {fields: fields}
        end

        result
      end

      sig { params(prop_info: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def extract_type_info(prop_info)
        # Extract type information from prop_info
        type_obj = prop_info[:type]
        type_str = type_obj.to_s

        # Check if this is optional (nilable)
        is_optional = type_str.include?("T.nilable")

        # Basic type information
        result = {optional: is_optional}

        # Determine the actual type
        if type_str.include?("LogStruct::LogLevel")
          result[:type] = "enum"
          result[:values] = "LogLevel"
        elsif type_str.include?("LogStruct::Source")
          result[:type] = "enum"
          result[:values] = "Source"
        elsif type_str.include?("LogStruct::LogEvent")
          result[:type] = "enum"
          result[:values] = "LogEvent"
        elsif type_str.include?("String")
          result[:type] = "string"
        elsif type_str.include?("Integer")
          result[:type] = "integer"
        elsif type_str.include?("Float")
          result[:type] = "number"
        elsif type_str.include?("Boolean") || type_str.include?("TrueClass") || type_str.include?("FalseClass")
          result[:type] = "boolean"
        elsif type_str.include?("Time")
          result[:type] = "string"
          result[:format] = "date-time"
        elsif type_str.include?("T::Array")
          result[:type] = "array"
          # Could extract item type here if needed
        elsif type_str.include?("T::Hash")
          result[:type] = "object"
          # Could extract key/value types here if needed
        else
          result[:type] = "any"
        end

        result
      end

      sig { params(field_info: T::Hash[Symbol, T.untyped]).returns(String) }
      def typescript_type_for(field_info)
        case field_info[:type]
        when "enum"
          field_info[:values]
        when "string"
          if field_info[:format] == "date-time"
            "string" # Could use Date, but string is more compatible
          else
            "string"
          end
        when "integer", "number"
          "number"
        when "boolean"
          "boolean"
        when "array"
          "any[]" # Could be more specific if we had item type
        when "object"
          "Record<string, any>"
        else
          "any"
        end
      end
    end
  end
end
