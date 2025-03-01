# typed: true
# frozen_string_literal: true

require "logger"
require "active_support/core_ext/object/blank"
require "json"
require "globalid"
require_relative "param_filters"
require_relative "logstop_fork"
require_relative "multi_error_reporter"

module RailsStructuredLogging
  # Formatter for structured logging that outputs logs as JSON
  # This is a port of the existing JSONLogFormatter with some improvements
  class LogFormatter < Logger::Formatter
    # Add current_tags method to support ActiveSupport::TaggedLogging
    def current_tags
      Thread.current[:activesupport_tagged_logging_tags] ||= []
    end

    # Add tagged method to support ActiveSupport::TaggedLogging
    def tagged(*tags)
      new_tags = tags.flatten
      current_tags.concat(new_tags) if new_tags.any?
      yield self
    ensure
      current_tags.pop(new_tags.size) if new_tags.any?
    end

    # Add clear_tags! method to support ActiveSupport::TaggedLogging
    def clear_tags!
      Thread.current[:activesupport_tagged_logging_tags] = []
    end

    def scrub_string(string)
      # Use our LogstopFork module to scrub sensitive information from strings
      RailsStructuredLogging::LogstopFork.scrub(string)
    end

    # Format ActiveJob arguments safely, similar to how Rails does it internally
    # Also scrubs sensitive information using LogstopFork
    def format_values(arg)
      @format_recursion_counter ||= 0
      # Prevent infinite recursion, just return args with no modifications
      return arg if @format_recursion_counter > 20

      case arg
      when Hash
        @format_recursion_counter += 1
        result = {}

        # Process each key-value pair
        arg.each do |key, value|
          # Check if this key should be filtered
          result[key] = if ParamFilters.should_filter_json_data?(key)
            # Filter the value
            {_filtered: ParamFilters.summarize_json_attribute(value)}
          else
            # Process the value normally
            format_values(value)
          end
        end

        result
      when Array
        @format_recursion_counter += 1
        result = arg.map { |value| format_values(value) }

        # Filter large arrays
        result = result.take(10) + ["... and #{result.size - 10} more items"] if result.size > 10

        result
      when GlobalID::Identification
        begin
          arg.to_global_id.to_s
        rescue
          begin
            "#{arg.class.name}(##{arg.id})"
          rescue => e
            MultiErrorReporter.report_exception(e)
            "[GlobalID Error]"
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

    def call(severity, time, progname, msg)
      @format_recursion_counter = 0

      # Use standardized field names
      data = msg.is_a?(Hash) ? msg.dup : {msg: msg.to_s}

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
    def generate_json(data)
      "#{data.to_json}\n"
    end
  end
end
