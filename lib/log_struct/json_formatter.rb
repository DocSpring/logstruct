# typed: strict
# frozen_string_literal: true

require "logger"
require "active_support/core_ext/object/blank"
require "json"
require "globalid"
require_relative "log_source"
require_relative "log_event"
require_relative "log_scrubber"
require_relative "log"
require_relative "param_filters"
require_relative "multi_error_reporter"

module LogStruct
  class JSONFormatter < Logger::Formatter
    extend T::Sig

    # Add current_tags method to support ActiveSupport::TaggedLogging
    sig { returns(T::Array[String]) }
    def current_tags
      Thread.current[:activesupport_tagged_logging_tags] ||= []
    end

    # Add tagged method to support ActiveSupport::TaggedLogging
    sig { params(tags: T::Array[String], blk: T.proc.params(formatter: JSONFormatter).void).returns(T.untyped) }
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

    sig { params(string: String).returns(String) }
    def scrub_string(string)
      # Use LogScrubber module to scrub sensitive information from strings
      LogScrubber.scrub(string)
    end

    sig { params(arg: T.untyped, recursion_depth: Integer).returns(T.untyped) }
    def format_values(arg, recursion_depth: 0)
      # Prevent infinite recursion in case any args have circular references
      # or are too deeply nested. Just return args.
      return arg if recursion_depth > 20

      case arg
      when Hash
        result = {}

        # Process each key-value pair
        arg.each do |key, value|
          # Check if this key should be filtered
          result[key] = if ParamFilters.should_filter_json_data?(key)
            # Filter the value
            {_filtered: ParamFilters.summarize_json_attribute(value)}
          else
            # Process the value normally
            format_values(value, recursion_depth: recursion_depth + 1)
          end
        end

        result
      when Array
        result = arg.map { |value| format_values(value, recursion_depth: recursion_depth + 1) }

        # Filter large arrays
        if result.size > 10
          result = result.take(10) + ["... and #{result.size - 10} more items"]
        end
        result
      when GlobalID::Identification
        begin
          arg.to_global_id
        rescue
          begin
            case arg
            when ActiveRecord::Base
              "#{arg.class}(##{arg.id})"
            else
              arg
            end
          rescue => e
            MultiErrorReporter.report_exception(e)
            "[GLOBALID_ERROR]"
          end
        end
      when LogSource, LogEvent
        arg.serialize
      when String
        scrub_string(arg)
      else
        arg
      end
    rescue => e
      MultiErrorReporter.report_exception(e)
      arg
    end

    sig { params(severity: String, time: Time, progname: T.nilable(String), log_value: T.untyped).returns(String) }
    def call(severity, time, progname, log_value)
      # Handle different types of log values
      data = case log_value
      when T::Struct
        # Convert T::Struct to a hash
        log_value.serialize
      when Hash
        # Use hash as is
        log_value.dup
      else
        # Create a Plain struct with the message and then serialize it
        plain = Log::Plain.new(
          msg: log_value.to_s,
          ts: time
        )
        plain.serialize
      end

      # Filter params, scrub sensitive values, format ActiveJob GlobalID arguments
      data = format_values(data)

      # Add standard fields if not already present
      data[:src] ||= "rails"
      data[:evt] ||= "log"
      data[:ts] ||= time.iso8601(3)
      data[:level] = severity.downcase
      data[:progname] = progname if progname.present?

      # Scrub any string messages
      data[:msg] = scrub_string(data[:msg]) if data[:msg].is_a?(String)

      generate_json(data)
    end

    # Output as JSON with a newline. We mock this method in tests so we can
    # inspect the data right before it gets turned into a JSON string.
    sig { params(data: T::Hash[T.untyped, T.untyped]).returns(String) }
    def generate_json(data)
      "#{data.to_json}\n"
    end
  end
end
