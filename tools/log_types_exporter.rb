# typed: strict
# frozen_string_literal: true

# cspell:ignore _tnilable
# rubocop:disable Sorbet/ConstantsFromStrings

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

      # Public method to export TypeScript definitions and JSON key mappings to files
      sig { void }
      def export
        # Export TypeScript definitions
        puts "Exporting LogStruct types to TypeScript..."
        puts "Output file: #{@output_ts_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(@output_ts_file))

        # Generate the TypeScript content
        content = generate_typescript_definitions

        # Write to file
        File.write(@output_ts_file, content)

        puts "Exported log types to #{@output_ts_file}"

        # Export LOG_KEYS mapping to JSON
        export_keys_to_json
      end

      # Export LOG_KEYS mapping to a JSON file
      sig { params(output_json_file: T.nilable(String)).void }
      def export_keys_to_json(output_json_file = nil)
        # Default to the same directory as the TypeScript file
        output_json_file ||= File.join(File.dirname(@output_ts_file), "log-keys.json")

        puts "Exporting LogStruct key mappings to JSON..."
        puts "Output file: #{output_json_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(output_json_file))

        # Convert LOG_KEYS to a format suitable for JSON
        # - Convert keys from symbols to strings
        # - Convert values from symbols to strings
        json_keys = LogStruct::LOG_KEYS.transform_keys(&:to_s).transform_values(&:to_s)

        # Write to file with pretty formatting
        File.write(output_json_file, JSON.pretty_generate(json_keys))

        puts "Exported key mappings to #{output_json_file}"
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

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def generate_data
        # Export everything as a hash
        {
          # Export all enum values from LogStruct module
          enums: export_enums,

          # Export log structs
          logs: export_log_structs
        }
      end

      # Find and export all T::Enum subclasses in the LogStruct module
      sig { returns(T::Hash[Symbol, T::Array[String]]) }
      def export_enums
        enum_hash = {}

        # Find all T::Enum subclasses in the LogStruct module
        T::Enum.subclasses
          .select { |klass| klass.name.to_s.start_with?("LogStruct::") }
          .each do |enum_class|
            # Extract enum name (last part of the class name)
            enum_name = enum_class.name.to_s.split("::").last&.to_sym
            next if enum_name.nil? # Skip if we couldn't get a valid name

            # Add enum values to the hash
            enum_hash[enum_name] = enum_class.values.map(&:serialize)
          end

        enum_hash
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
        
        # Collect all event union types to generate arrays later
        log_event_arrays = {}
        
        data[:logs].each do |log_type, log_info|
          ts_content << "export interface #{log_type}Log {"
          
          # Collect valid event types if this log has an enum_union for events
          event_field_info = log_info[:fields][:event]
          if event_field_info && 
             event_field_info[:type] == "enum_union" &&
             event_field_info[:base_enum] == "LogEvent" && 
             event_field_info[:enum_values]&.any?
            
            log_event_arrays[log_type] = event_field_info[:enum_values].map do |value|
              # Map Ruby enum names to TypeScript enum values (e.g., "IPSpoof" -> "LogEvent.IP_SPOOF")
              case value
              when "IPSpoof" then "LogEvent.IP_SPOOF"
              when "CSRFViolation" then "LogEvent.CSRF_VIOLATION" 
              else
                # Default conversion of StudlyCaps to SCREAMING_SNAKE_CASE
                "LogEvent.#{value.gsub(/([a-z])([A-Z])/, '\1_\2').upcase}"
              end
            end
          end
          
          # Output all fields with types
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
        ts_content << ""
        
        # Add event arrays for each log type that has an enum_union
        ts_content << "// Event type arrays for log types"
        log_event_arrays.each do |log_type, event_values|
          # Create a type-safe array with a specific union type for each log type's events
          union_type = event_values.join(" | ")
          ts_content << "export const #{log_type}LogEvents: Array<#{union_type}> = ["
          event_values.each do |event|
            ts_content << "  #{event},"
          end
          ts_content << "];"
          ts_content << ""
        end

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

        # Debug logging for complex types
        # if type_str.include?("T.any") || type_str.include?("SecurityLogEvent")
        #   puts "Extracting type info for: #{type_str}"
        #   puts "Type object class: #{type_obj.class}"
        #   puts "Type object inspect: #{type_obj.inspect}"
        # end

        # Check for TypedHash specifically (handles metadata field correctly)
        if type_obj.is_a?(T::Types::TypedHash) || type_obj.instance_of?(::T::Types::TypedHash)
          return {optional: prop_info[:_tnilable] || false, type: "object"}
        end

        # Check if this is optional (nilable)
        is_optional = type_str.include?("T.nilable")

        # Basic type information
        result = {optional: is_optional}

        # Check for direct enum values (single value restriction case)
        # For example: const :source, Source::Job, default: T.let(Source::Job, Source::Job)
        if type_obj.is_a?(T::Enum) || type_obj.class&.ancestors&.include?(T::Enum)
          # This is a direct reference to a specific enum value (not a type)
          # Extract the enum class and the specific value
          enum_class = type_obj.class
          enum_name = enum_class.name.to_s.split("::").last

          # Get the enum value name by finding which constant in the enum class has this value
          enum_value_name = T.let(nil, T.nilable(String))
          enum_class.constants.each do |const_name|
            if enum_class.const_get(const_name) == type_obj
              enum_value_name = const_name.to_s
              break
            end
          end

          # For example: LogStruct::Source::Job => { type: "enum_single", base_enum: "Source", enum_value: "Job" }
          result[:type] = "enum_single"
          result[:base_enum] = enum_name
          result[:enum_value] = enum_value_name

          return result
        # Check for T::Types::TEnum with a specific enum value
        elsif type_obj.is_a?(T::Types::TEnum) && type_str.include?("::") && !type_str.include?("T.nilable")
          # Handle specific enum types like LogStruct::Source::Job
          # The type string will look like "LogStruct::Source::Job"
          parts = type_str.split("::")

          if parts.size >= 3
            # Extract the enum name and specific value
            enum_name = parts[-2]
            enum_value_name = parts[-1]

            # For example: LogStruct::Source::Job => { type: "enum_single", base_enum: "Source", enum_value: "Job" }
            result[:type] = "enum_single"
            result[:base_enum] = enum_name
            result[:enum_value] = enum_value_name

            return result
          end
        # Detect union types (T.any) or type aliases
        elsif type_str.include?("T.any(") || type_str.include?("LogStruct::Log::")
          # First, try to extract the base enum type (LogEvent, LogLevel, Source)
          base_enum = nil
          enum_values = []

          # Check if it's a LogEvent union type
          if type_str.include?("LogEvent::")
            base_enum = "LogEvent"
            enum_module = LogStruct::LogEvent
          elsif type_str.include?("LogLevel::")
            base_enum = "LogLevel"
            enum_module = LogStruct::LogLevel
          elsif type_str.include?("Source::")
            base_enum = "Source"
            enum_module = LogStruct::Source
          end

          if base_enum
            result[:type] = "enum_union"
            result[:base_enum] = base_enum

            # Try to parse values from the T.any(...) format for direct T.any usage
            if type_str =~ /T\.any\(([^)]+)\)/
              values_str = $1
              # Regex to extract enum constants like LogEvent::IPSpoof
              values_str.scan(/#{base_enum}::([A-Za-z0-9_]+)/) do |match|
                enum_values << match.first
              end
            end

            # For type aliases like SecurityLogEvent, try to resolve the alias
            if enum_values.empty? && type_str =~ /LogStruct::Log::([A-Za-z0-9_]+)::([A-Za-z0-9_]+LogEvent)/
              log_class_name = $1
              type_alias_name = $2

              # Try to get the type alias from the log class
              log_class = begin
                Object.const_get("LogStruct::Log::#{log_class_name}")
              rescue
                nil
              end
              if log_class&.const_defined?(type_alias_name)
                # Try to resolve the type alias through the class hierarchy
                begin
                  # Look at the type alias to extract the enum values
                  # This is specific to LogStruct's enum pattern where the type alias is defined using T.any()
                  # For this to work, we need to open up the class and extract the type alias content

                  # Check if there are any constants in the LogEvent module that have this value in their name
                  enum_module.constants.each do |const_name|
                    # Check if this constant is used in the type definition at all
                    potential_match = "#{base_enum}::#{const_name}"
                    if type_str.include?(potential_match)
                      enum_values << const_name.to_s
                    end
                  end
                rescue => e
                  # Log the error for debugging but continue with what we have
                  puts "Error resolving type alias #{type_alias_name}: #{e.message}" if ENV["DEBUG"]
                end
              end
            end

            result[:enum_values] = enum_values unless enum_values.empty?
          else
            # Handle other types of unions that aren't enum-based
            result[:type] = "any"
          end
        # Standard type handling for simple types
        elsif type_str.include?("LogStruct::LogLevel")
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
            result[:item_type] = if item_type.include?("String")
              "string"
            elsif item_type.include?("Integer")
              "integer"
            elsif item_type.include?("Float")
              "number"
            elsif item_type.include?("Boolean") || item_type.include?("TrueClass") || item_type.include?("FalseClass")
              "boolean"
            else
              "any"
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
        # puts "Enum values: #{result[:enum_values]}" if result[:enum_values]

        result
      end

      sig { params(field_info: T::Hash[Symbol, T.untyped]).returns(String) }
      def typescript_type_for(field_info)
        case field_info[:type]
        when "enum"
          field_info[:values]
        when "enum_single"
          # Handle single enum value restriction
          # (e.g., const :source, Source::Job, default: T.let(Source::Job, Source::Job))
          if field_info[:base_enum] && field_info[:enum_value]
            # Create a specific enum value reference like: Source.JOB
            "#{field_info[:base_enum]}.#{field_info[:enum_value].upcase}"
          else
            # Fallback to the base enum if we couldn't extract the specific value
            field_info[:base_enum] || "any"
          end
        when "enum_union"
          # Handle union of enum values
          if field_info[:base_enum] && field_info[:enum_values]
            # Create a union type like: LogEvent.IP_SPOOF | LogEvent.CSRF_VIOLATION | LogEvent.BLOCKED_HOST
            field_info[:enum_values].map do |value|
              # Get the Ruby enum object for the given value name (e.g., LogEvent::IPSpoof)
              enum_class = case field_info[:base_enum]
              when "LogEvent" then LogStruct::LogEvent
              when "LogLevel" then LogStruct::LogLevel
              when "Source" then LogStruct::Source
              else nil
              end

              if enum_class
                # Look up the actual enum value to get its serialized form
                enum_value = begin
                  enum_class.const_get(value)
                rescue NameError
                  nil
                end

                # Convert to TypeScript enum constant (serialized value -> uppercase)
                serialized = enum_value&.serialize&.upcase || value.upcase
                "#{field_info[:base_enum]}.#{serialized}"
              else
                # Fallback if we can't find the enum class
                "#{field_info[:base_enum]}.#{value.upcase}"
              end
            end.join(" | ")
          else
            # Fallback to the base enum if we couldn't extract specific values
            field_info[:base_enum] || "any"
          end
        when "string"
          if field_info[:format] == "date-time"
          end
          "string"
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
# rubocop:enable Sorbet/ConstantsFromStrings
