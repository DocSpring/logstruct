# typed: strict
# frozen_string_literal: true

# cspell:ignore _tnilable
# rubocop:disable Sorbet/ConstantsFromStrings

# Load LogStruct type definitions
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct"

require "json"
require "fileutils"
require "time"

module LogStruct
  module Tools
    class LogTypesExporter
      extend T::Sig

      DEFAULT_OUTPUT_TS_FILE = "site/lib/log-generation/generated/log-types.ts"

      # Constructor with optional override for log struct classes (for testing)
      sig { params(output_ts_file: String, log_struct_classes: T.nilable(T::Array[T::Class[T::Struct]])).void }
      def initialize(output_ts_file = DEFAULT_OUTPUT_TS_FILE, log_struct_classes = nil)
        @output_ts_file = output_ts_file
        @log_struct_classes = log_struct_classes
      end

      # Public method to export TypeScript definitions and JSON key mappings to files
      sig { void }
      def export
        # Get the data once and reuse for all exports
        data = generate_data

        # Export TypeScript definitions
        puts "Exporting LogStruct types to TypeScript..."
        puts "Output file: #{@output_ts_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(@output_ts_file))

        # Generate the TypeScript content
        content = generate_typescript(data)

        # Write to file
        File.write(@output_ts_file, content)

        puts "Exported log types to #{@output_ts_file}"

        # Export LogField mapping to JSON
        export_keys_to_json

        # Export enums and log structs to JSON
        export_data_to_json(data)
      end

      # Export LogField mapping to a JSON file
      sig { params(output_json_file: T.nilable(String)).void }
      def export_keys_to_json(output_json_file = nil)
        # Default to the same directory as the TypeScript file
        output_json_file ||= File.join(File.dirname(@output_ts_file), "log-fields.json")

        puts "Exporting LogStruct key mappings to JSON..."
        puts "Output file: #{output_json_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(output_json_file))

        # Build mapping from LogField enum to serialized keys
        json_keys = {}
        LogStruct::LogField.values.each do |val|
          const_name = LogStruct::LogField.constants.find { |cn| LogStruct::LogField.const_get(cn) == val }&.to_s
          next unless const_name
          json_keys[const_name] = val.serialize.to_s
        end

        # Write to file with pretty formatting
        File.write(output_json_file, JSON.pretty_generate(json_keys))

        puts "Exported key mappings to #{output_json_file}"

        # Also export a property-name -> LogField enum name mapping for the frontend runtime
        export_property_to_logfield_json
      end

      # Export both enums and log structs to JSON files
      sig { params(data: T::Hash[Symbol, T.untyped]).void }
      def export_data_to_json(data)
        # Export enums to JSON
        export_enums_to_json(data[:enums])

        # Export log structs to JSON
        export_log_structs_to_json(data[:logs])
      end

      # Export a JSON mapping from TypeScript property names to compact JSON keys
      sig { params(output_json_file: T.nilable(String)).void }
      def export_property_to_logfield_json(output_json_file = nil)
        output_json_file ||= File.join(File.dirname(@output_ts_file), "prop-to-logfield.json")

        # Build property -> compact key mapping by walking exported structs
        logs = export_log_structs

        # Helper to camelize to PascalCase (from snake_case)
        camel = ->(str) { str.to_s.split("_").map { |s| s[0] ? s[0].upcase + s[1..] : s }.join }

        json = {}
        logs.each do |_type_name, info|
          info[:fields].each do |prop_name, _field_info|
            # Map TS property name to LogField constant name
            lf_name = if prop_name.to_s == "method"
              "HttpMethod"
            else
              camel.call(prop_name)
            end

            # Look up compact key via LogField enum when possible
            begin
              lf_const = LogStruct::LogField.const_get(lf_name)
              # Store the enum constant name as string
              json[prop_name.to_s] ||= lf_const.class.constants.find { |cn| lf_const.class.const_get(cn) == lf_const }.to_s
            rescue NameError
              # Ignore fields without LogField mapping (e.g., additional_data)
            end
          end
        end

        FileUtils.mkdir_p(File.dirname(output_json_file))
        File.write(output_json_file, JSON.pretty_generate(json))
        puts "Exported property to LogField mappings to #{output_json_file}"
      end

      # Export Sorbet enums to a JSON file
      sig { params(enums_data: T::Hash[Symbol, T::Array[String]], output_json_file: T.nilable(String)).void }
      def export_enums_to_json(enums_data, output_json_file = nil)
        # Default to the same directory as the TypeScript file
        output_json_file ||= File.join(File.dirname(@output_ts_file), "sorbet-enums.json")

        puts "Exporting Sorbet enums to JSON..."
        puts "Output file: #{output_json_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(output_json_file))

        # Format enum data for JSON
        json_enum_data = {}

        # For each enum, get the full class name and values
        T::Enum.subclasses
          .select { |klass| klass.name.to_s.start_with?("LogStruct::") }
          .each do |enum_class|
            # Get the full enum name (e.g., "LogStruct::Level")
            full_name = enum_class.name.to_s

            # Get the simple name (e.g., "Level")
            simple_name = full_name.split("::").last

            # Skip if we don't have data for this enum
            next unless simple_name && enums_data.key?(simple_name.to_sym)

            # Map enum values to their constant names
            values_with_names = enum_class.values.map do |value|
              constant_name = enum_class.constants.find { |const_name| enum_class.const_get(const_name) == value }&.to_s
              serialized = value.serialize

              # Return a hash with name and value
              {
                name: constant_name,
                value: serialized
              }
            end

            # Add to the JSON data
            json_enum_data[full_name] = values_with_names
          end

        # Write to file with pretty formatting
        File.write(output_json_file, JSON.pretty_generate(json_enum_data))

        puts "Exported Sorbet enums to #{output_json_file}"
      end

      # Export LogStruct log structs to a JSON file
      sig { params(logs_data: T::Hash[String, T::Hash[Symbol, T.untyped]], output_json_file: T.nilable(String)).void }
      def export_log_structs_to_json(logs_data, output_json_file = nil)
        # Default to the same directory as the TypeScript file
        output_json_file ||= File.join(File.dirname(@output_ts_file), "sorbet-log-structs.json")

        puts "Exporting LogStruct log structs to JSON..."
        puts "Output file: #{output_json_file}"

        # Create output directory if needed
        FileUtils.mkdir_p(File.dirname(output_json_file))

        # Format structs data for JSON
        json_structs_data = {}

        # Process each log struct class
        logs_data.each do |struct_name, struct_info|
          # Get the full class name
          full_name = "LogStruct::Log::#{struct_name}"

          # Add to the structs data
          json_structs_data[full_name] = {
            name: struct_name,
            fields: struct_info[:fields].transform_keys(&:to_s)
          }
        end

        # Write to file with pretty formatting
        File.write(output_json_file, JSON.pretty_generate(json_structs_data))

        puts "Exported LogStruct log structs to #{output_json_file}"
      end

      # Public method to generate TypeScript definitions as a string
      # This is the method we can test easily without file I/O
      sig { returns(String) }
      def generate_typescript_definitions
        # Get the data
        data = generate_data

        # Transform data to TypeScript
        generate_typescript(data)
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
          enum_values.sort.each do |value|
            ts_content << "  #{value.upcase} = \"#{value}\","
          end
          ts_content << "}"
          ts_content << ""
        end

        # Add LogType enum
        ts_content << "// Log Types"
        ts_content << "export enum LogType {"
        data[:logs].keys.sort.each do |log_type|
          ts_content << "  #{log_type.upcase} = \"#{log_type}\","
        end
        ts_content << "}"
        ts_content << ""

        # Add array of all log types for iteration
        ts_content << "// Array of all log types for iteration"
        ts_content << "export const AllLogTypes: Array<LogType> = ["
        data[:logs].keys.sort.each do |log_type|
          ts_content << "  LogType.#{log_type.upcase},"
        end
        ts_content << "];"
        ts_content << ""

        # Add property -> LogField mapping
        # Build from exported logs data
        prop_map = {}
        data[:logs].each do |_type, info|
          info[:fields].each_key do |prop_name|
            lf_name = if prop_name.to_s == "method"
              "HttpMethod"
            else
              prop_name.to_s.split("_").map { |s| s[0] ? s[0].upcase + s[1..] : s }.join
            end
            begin
              lf_const = LogStruct::LogField.const_get(lf_name)
              compact = lf_const.serialize.to_s
              member = compact.upcase.gsub(/[^A-Z0-9]/, "_")
              prop_map[prop_name.to_s] = member
            rescue NameError
              # skip if not a LogField
            end
          end
        end
        ts_content << "export const PropToLogField: Readonly<Record<string, LogField>> = {"
        prop_map.keys.sort.each do |prop|
          member = prop_map[prop]
          ts_content << "  #{prop.inspect}: LogField.#{member},"
        end
        ts_content << "} as const;"
        ts_content << ""

        # Add interface for each log type
        ts_content << "// Log Interfaces"

        # Collect all event union types to generate arrays later
        event_arrays = {}

        data[:logs].each do |log_type, log_info|
          ts_content << "export interface #{log_type}Log {"

          # Collect valid event types if this log has an enum_union for events
          event_field_info = log_info[:fields][:event]
          if event_field_info &&
              event_field_info[:type] == "enum_union" &&
              event_field_info[:base_enum] == "Event" &&
              event_field_info[:enum_values]&.any?

            event_arrays[log_type] = event_field_info[:enum_values].map do |value|
              # Map Ruby enum names to TypeScript enum values (e.g., "IPSpoof" -> "Event.IP_SPOOF")
              case value
              when "IPSpoof" then "Event.IP_SPOOF"
              when "CSRFViolation" then "Event.CSRF_VIOLATION"
              else
                # Default conversion of StudlyCaps to SCREAMING_SNAKE_CASE
                "Event.#{value.gsub(/([a-z])([A-Z])/, '\1_\2').upcase}"
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
        log_types = data[:logs].keys.sort.map { |type| "  | #{type}Log" }
        ts_content << log_types.join("\n")
        ts_content << ";"
        ts_content << ""

        # Add event arrays for each log type that has an enum_union
        ts_content << "// Event type arrays for log types"
        event_arrays.each do |log_type, event_values|
          # Create a type-safe array with a specific union type for each log type's events
          union_type = event_values.join(" | ")
          ts_content << "export const #{log_type}Events: Array<#{union_type}> = ["
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
        # Group structs by top-level log type (e.g., ActiveJob, Security)
        groups = {}

        T::Struct.subclasses
          .select { |klass| klass.name.to_s.start_with?("LogStruct::Log::") }
          .each do |log_class|
            parts = log_class.name.to_s.split("::")
            type_name = parts[2] # e.g., "Request" or "ActiveJob"
            type_name = parts[3] if parts.length > 4 # nested event class -> parent name

            groups[type_name] ||= {fields: {}, events: []}

            # Collect field info from this concrete struct
            fields = groups[type_name][:fields]
            log_class.props.each do |field_name, prop_info|
              # Normalize http_method for Request
              field_key = field_name
              field_key = :method if field_name == :http_method && type_name == "Request"

              type_info = extract_type_info(prop_info)

              # Capture event enum values for union arrays
              if field_name == :event && type_info[:type] == "enum_single" && type_info[:enum_value]
                groups[type_name][:events] << type_info[:enum_value]
              end

              # Prefer existing definitions; only fill in missing fields
              fields[field_key] ||= type_info
            end
          end

        # Synthesize event union for each group that has multiple events
        result = {}
        groups.each do |type_name, data|
          fields = data[:fields]
          events = data[:events].uniq
          if events.any?
            fields[:event] = {
              type: "enum_union",
              base_enum: "Event",
              enum_values: events
            }
          end
          result[type_name] = {fields: fields}
        end

        result
      end

      sig { params(prop_info: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def extract_type_info(prop_info)
        # Extract type information from prop_info
        type_obj = prop_info[:type]
        type_str = type_obj.to_s

        # Debug logging for complex types
        # if type_str.include?("T.any") || type_str.include?("SecurityEvent")
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
          # First, try to extract the base enum type (Event, Level, Source)
          base_enum = nil
          enum_values = []

          # Check if it's a Event union type
          if type_str.include?("Event::")
            base_enum = "Event"
            enum_module = LogStruct::Event
          elsif type_str.include?("Level::")
            base_enum = "Level"
            enum_module = LogStruct::Level
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
              # Regex to extract enum constants like Event::IPSpoof
              values_str.scan(/#{base_enum}::([A-Za-z0-9_]+)/) do |match|
                enum_values << match.first
              end
            end

            # For type aliases like SecurityEvent, try to resolve the alias
            if enum_values.empty? && type_str =~ /LogStruct::Log::([A-Za-z0-9_]+)::([A-Za-z0-9_]+Event)/
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

                  # Check if there are any constants in the Event module that have this value in their name
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
        elsif type_str.include?("LogStruct::Level")
          result[:type] = "enum"
          result[:values] = "Level"
        elsif type_str.include?("LogStruct::Source")
          result[:type] = "enum"
          result[:values] = "Source"
        elsif type_str.include?("LogStruct::Event")
          result[:type] = "enum"
          result[:values] = "Event"
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
            # Create a union type like: Event.IP_SPOOF | Event.CSRF_VIOLATION | Event.BLOCKED_HOST
            field_info[:enum_values].map do |value|
              # Get the Ruby enum object for the given value name (e.g., Event::IPSpoof)
              enum_class = case field_info[:base_enum]
              when "Event" then LogStruct::Event
              when "Level" then LogStruct::Level
              when "Source" then LogStruct::Source
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
