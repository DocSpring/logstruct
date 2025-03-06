# typed: strict
# frozen_string_literal: true

# Load LogStruct type definitions
require_relative "../lib/log_struct"

require "json"
require "fileutils"
require "time"

module LogStruct
  module Tools
    class LogTypesExporter
      extend T::Sig

      DEFAULT_OUTPUT_TS_FILE = "site/lib/log-generation/log-types.ts"

      # Constructor with optional override for log struct classes (for testing)
      sig { params(output_ts_file: String, log_struct_classes: T.nilable(T::Array[T::Class[T::Struct]])).void }
      def initialize(output_ts_file = DEFAULT_OUTPUT_TS_FILE, log_struct_classes = nil)
        @output_ts_file = output_ts_file
        @log_struct_classes = log_struct_classes
      end

      # Public method to export TypeScript definitions to file
      sig { void }
      def export
        puts "Exporting LogStruct types to TypeScript..."
        puts "Output file: #{@output_ts_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(@output_ts_file))

        # Generate the TypeScript content
        content = generate_typescript_definitions

        # Write to file
        File.write(@output_ts_file, content)

        puts "Exported log types to #{@output_ts_file}"
      end
      
      # Public method to generate TypeScript definitions as a string
      # This is the method we can test easily without file I/O
      sig { returns(String) }
      def generate_typescript_definitions
        # Get the data
        log_types_data = generate_data
        
        # Transform data to TypeScript
        generate_typescript(log_types_data)
      end

      # Make these methods private but expose for testing via `public_send`
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
      private :generate_data

      sig { params(data: T::Hash[Symbol, T.untyped]).returns(String) }
      def generate_typescript(data)
        ts_content = []

        # Add file header (We need 'any' for a lot of unstructured Hashes and Arrays)
        ts_content << "/* eslint-disable @typescript-eslint/no-explicit-any */"
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

        # Return the TypeScript content as a string
        ts_content.join("\n")
      end
      private :generate_typescript

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
        
        # Uncomment for debugging
        # puts "Extracting type info for: #{type_str}"
        # puts "Array key present? #{prop_info.key?(:array)}" if prop_info.key?(:array)
        # puts "Array value: #{prop_info[:array]}" if prop_info.key?(:array)
        
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
        elsif type_str.include?("T::Array") || type_str.include?("TypedArray") || (type_str == "T::Array[String]") || prop_info.key?(:array)
          result[:type] = "array"
          
          # Get array item type if available
          if prop_info[:array]
            item_type = prop_info[:array].to_s
            if item_type.include?("String")
              result[:item_type] = "string"
            elsif item_type.include?("Integer")
              result[:item_type] = "integer"
            elsif item_type.include?("Float")
              result[:item_type] = "number"
            elsif item_type.include?("Boolean") || item_type.include?("TrueClass") || item_type.include?("FalseClass")
              result[:item_type] = "boolean"
            else
              result[:item_type] = "any"
            end
          end
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
        elsif type_str.include?("T::Hash")
          result[:type] = "object"
          # Could extract key/value types here if needed
        else
          result[:type] = "any"
        end

        # Uncomment for debugging
        # puts "Detected type: #{result[:type]}"
        # puts "Item type: #{result[:item_type]}" if result[:item_type]
        
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
          if field_info[:item_type]
            "#{field_info[:item_type]}[]"
          else
            "any[]"
          end
        when "object"
          "Record<string, any>"
        else
          "any"
        end
      end
    end
  end
end
