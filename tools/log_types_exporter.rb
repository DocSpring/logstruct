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

      DEFAULT_OUTPUT_FILE = "site/lib/log_types.json"

      sig { params(output_file: String).void }
      def initialize(output_file = DEFAULT_OUTPUT_FILE)
        @output_file = output_file
      end

      sig { void }
      def export
        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(@output_file))

        # Export everything as JSON
        result = {
          # Export enum values
          enums: {
            LogLevel: LogStruct::LogLevel.values.map(&:serialize),
            Source: LogStruct::Source.values.map(&:serialize),
            LogEvent: LogStruct::LogEvent.values.map(&:serialize)
          },

          # Export log structs
          logs: export_log_structs
        }

        # Write to file
        File.write(@output_file, JSON.pretty_generate(result))
        puts "Exported log types to #{@output_file}"
      end

      private

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
    end
  end
end
