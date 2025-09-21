# typed: strict
# frozen_string_literal: true

require "logger"
require "active_support/core_ext/object/blank"
require "json"
require "globalid"
require_relative "enums/source"
require_relative "enums/event"
require_relative "string_scrubber"
require_relative "log"
require_relative "param_filters"
require_relative "multi_error_reporter"

module LogStruct
  class Formatter < ::Logger::Formatter
    extend T::Sig

    # Add current_tags method to support ActiveSupport::TaggedLogging
    sig { returns(T::Array[String]) }
    def current_tags
      Thread.current[:activesupport_tagged_logging_tags] ||= []
    end

    # Add tagged method to support ActiveSupport::TaggedLogging
    sig { params(tags: T::Array[String], blk: T.proc.params(formatter: Formatter).void).returns(T.untyped) }
    def tagged(*tags, &blk)
      new_tags = tags.flatten
      current_tags.concat(new_tags) if new_tags.any?
      yield self
    ensure
      current_tags.pop(new_tags.size) if new_tags&.any?
    end

    # Add clear_tags! method to support ActiveSupport::TaggedLogging
    sig { void }
    def clear_tags!
      Thread.current[:activesupport_tagged_logging_tags] = []
    end

    sig { params(tags: T::Array[String]).returns(T.untyped) }
    def push_tags(*tags)
      current_tags.concat(tags)
    end

    sig { params(string: String).returns(String) }
    def scrub_string(string)
      # Use StringScrubber module to scrub sensitive information from strings
      StringScrubber.scrub(string)
    end

    sig { params(arg: T.untyped, recursion_depth: Integer).returns(T.untyped) }
    def process_values(arg, recursion_depth: 0)
      # Prevent infinite recursion in case any args have circular references
      # or are too deeply nested. Just return args.
      return arg if recursion_depth > 20

      case arg
      when Hash
        result = {}

        # Process each key-value pair
        arg.each do |key, value|
          # Check if this key should be filtered at any depth
          result[key] = if ParamFilters.should_filter_key?(key, value)
            # Filter the value
            {_filtered: ParamFilters.summarize_json_attribute(key, value)}
          else
            # Process the value normally
            process_values(value, recursion_depth: recursion_depth + 1)
          end
        end

        result
      when Array
        process_array(arg, recursion_depth: recursion_depth)
      when GlobalID::Identification
        begin
          arg.to_global_id
        rescue
          begin
            case arg
            when ActiveRecord::Base
              "#{arg.class}(##{arg.id})"
            else
              # For non-ActiveRecord objects that failed to_global_id, try to get a string representation
              # If this also fails, we want to catch it and return the error placeholder
              String(T.cast(arg, Object))
            end
          rescue => e
            LogStruct.handle_exception(e, source: Source::Internal)
            "[GLOBALID_ERROR]"
          end
        end
      when Source, Event
        arg.serialize
      when String
        scrub_string(arg)
      when Time
        arg.iso8601(3)
      else
        # Any other type (e.g. Symbol, Integer, Float, Boolean etc.)
        arg
      end
    rescue => e
      # Report error through LogStruct's framework
      context = {
        processor_method: "process_values",
        value_type: arg.class.name,
        recursion_depth: recursion_depth
      }
      LogStruct.handle_exception(e, source: Source::Internal, context: context)
      arg
    end

    sig { params(log_value: T.untyped, time: Time).returns(T::Hash[Symbol, T.untyped]) }
    def log_value_to_hash(log_value, time:)
      case log_value
      when Log::Interfaces::CommonFields
        # Our log classes all implement a custom #serialize method that use symbol keys
        log_value.serialize

      when T::Struct
        # Default T::Struct.serialize methods returns a hash with string keys, so convert them to symbols
        log_value.serialize.deep_symbolize_keys

      when Hash
        # Use hash as is and convert string keys to symbols
        log_value.dup.deep_symbolize_keys

      else
        # Create a Plain log with the message as a string and serialize it with symbol keys
        # log_value can be literally anything: Integer, Float, Boolean, NilClass, etc.
        log_message = case log_value
        # Handle all the basic types without any further processing
        when String, Symbol, TrueClass, FalseClass, NilClass, Array, Hash, Time, Numeric
          log_value
        else
          # Handle the serialization of complex objects in a useful way:
          #
          # 1. For ActiveRecord models: Use as_json which includes attributes
          # 2. For objects with custom as_json implementations: Use their implementation
          # 3. For basic objects that only have ActiveSupport's as_json: Use to_s
          begin
            method_owner = log_value.method(:as_json).owner

            # If it's ActiveRecord, ActiveModel, or a custom implementation, use as_json
            if method_owner.to_s.include?("ActiveRecord") ||
                method_owner.to_s.include?("ActiveModel") ||
                method_owner.to_s.exclude?("ActiveSupport::CoreExtensions") &&
                    method_owner.to_s.exclude?("Object")
              log_value.as_json
            else
              # For plain objects with only the default ActiveSupport as_json
              log_value.to_s
            end
          rescue => e
            # Handle serialization errors
            context = {
              object_class: log_value.class.name,
              object_inspect: log_value.inspect.truncate(100)
            }
            LogStruct.handle_exception(e, source: Source::Internal, context: context)

            # Fall back to the string representation to ensure we continue processing
            log_value.to_s
          end
        end

        Log::Plain.new(
          message: log_message,
          timestamp: time
        ).serialize
      end
    end

    # Serializes Log (or string) into JSON
    sig { params(severity: T.any(String, Symbol, Integer), time: Time, progname: T.nilable(String), log_value: T.untyped).returns(String) }
    def call(severity, time, progname, log_value)
      level_enum = Level.from_severity(severity)

      data = log_value_to_hash(log_value, time: time)

      # Filter params, scrub sensitive values, format ActiveJob GlobalID arguments
      data = process_values(data)

      # Add standard fields if not already present
      data[:src] ||= Source::App
      data[:evt] ||= Event::Log
      data[:ts] ||= time.iso8601(3)
      data[:lvl] = level_enum # Set level from severity parameter
      data[:prog] = progname if progname.present?

      generate_json(data)
    end

    # Output as JSON with a newline. We mock this method in tests so we can
    # inspect the data right before it gets turned into a JSON string.
    sig { params(data: T::Hash[T.untyped, T.untyped]).returns(String) }
    def generate_json(data)
      "#{data.to_json}\n"
    end

    sig { params(array: T::Array[T.untyped], recursion_depth: Integer).returns(T::Array[T.untyped]) }
    def process_array(array, recursion_depth:)
      return [] if array.empty?

      if looks_like_backtrace_array?(array)
        array.map { |value| process_values(value, recursion_depth: recursion_depth + 1) }
      else
        processed = []
        array.each_with_index do |value, index|
          break if index >= 10

          processed << process_values(value, recursion_depth: recursion_depth + 1)
        end

        if array.size > 10
          processed << "... and #{array.size - 10} more items"
        end

        processed
      end
    end

    # Check if an array looks like a backtrace (array of strings with file:line pattern)
    sig { params(array: T::Array[T.untyped]).returns(T::Boolean) }
    def looks_like_backtrace_array?(array)
      backtrace_like_count = array.first(5).count do |element|
        element.is_a?(String) && element.match?(/\A[^:\s]+:\d+/)
      end

      backtrace_like_count >= 3
    end
  end
end
