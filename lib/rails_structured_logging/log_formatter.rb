# typed: strict
# frozen_string_literal: true

require "logger"
require "active_support/core_ext/object/blank"
require "json"
require "globalid"

module RailsStructuredLogging
  # Formatter for structured logging that outputs logs as JSON
  # This is a port of the existing JSONLogFormatter with some improvements
  class LogFormatter < Logger::Formatter
    # Format ActiveJob arguments safely, similar to how Rails does it internally
    # Also scrubs sensitive information using LogstopFork
    LogValueType = T.type_alias {
      T.any(
        T::Boolean,
        T::Hash[T.untyped, T.untyped],
        T::Array[T.untyped],
        GlobalID::Identification,
        String,
        Integer,
        Float,
        Symbol
      )
    }

    LogHashType = T.type_alias {
      T::Hash[Symbol, T.any(
        T::Boolean,
        T::Hash[T.untyped, T.untyped],
        T::Array[T.untyped],
        GlobalID::Identification,
        String,
      {symbol1: Type1, symbol2: Type2}
    }

    # Can call Rails.logger.info with either a structured hash or a plain string
    LogDataType = T.type_alias {
      T.any(
        String,
        T::Hash[T.untyped, T.untyped]
      )
    }

    # Add current_tags method to support ActiveSupport::TaggedLogging
    sig { returns(T::Array[String]) }
    def current_tags
      Thread.current[:activesupport_tagged_logging_tags] ||= []
    end

    # Add tagged method to support ActiveSupport::TaggedLogging
    sig { params(tags: T::Array[String]).returns(LogFormatter) }
    def tagged(*tags)
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
      # Use our LogstopFork module to scrub sensitive information from strings
      RailsStructuredLogging::LogstopFork.scrub(string)
    end

    sig { params(arg: LogValueType, recursion_depth: Integer).returns(LogValueType) }
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
      when String
        scrub_string(arg)
      else
        arg
      end
    rescue => e
      MultiErrorReporter.report_exception(e)
      arg
    end

    sig { params(severity: String, time: Time, progname: String, msg: LogValueType).returns(String) }
    def call(severity, time, progname, log_value)
      # Use standardized field names
      data = T.let(msg.is_a?(Hash) ? msg.dup : {msg: msg.to_s}, LogValueType)

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
