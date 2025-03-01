# frozen_string_literal: true

require 'logger'
require 'active_support/core_ext/object/blank'
require 'active_support/json'
require_relative 'param_filters'
require_relative 'logstop_fork'

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
      if new_tags.any?
        current_tags.concat(new_tags)
        yield
      else
        yield
      end
    ensure
      current_tags.pop(new_tags.size) if new_tags.any?
    end

    # Add clear_tags! method to support ActiveSupport::TaggedLogging
    def clear_tags!
      Thread.current[:activesupport_tagged_logging_tags] = []
    end

    # Format the log message
    def call(severity, timestamp, progname, msg)
      # Use our LogstopFork module to scrub sensitive information from strings
      if msg.is_a?(String)
        msg = RailsStructuredLogging::LogstopFork.scrub(msg)
      end

      # Convert to a hash if it's not already one
      data = msg.is_a?(Hash) ? msg.dup : { msg: msg.to_s }

      # Add standard fields
      data[:level] ||= severity&.downcase
      data[:ts] ||= timestamp.strftime('%Y-%m-%dT%H:%M:%S.%3N%z')
      data[:pid] ||= Process.pid

      # Add tags if present
      if current_tags.any?
        data[:tags] ||= current_tags.dup
      end

      # Add progname if present
      data[:progname] = progname if progname.present?

      # Scrub sensitive data from string values
      scrub_sensitive_data(data)

      # Filter sensitive parameters
      filter_sensitive_params(data)

      # Convert to JSON
      "#{generate_json(data)}\n"
    rescue => e
      # If JSON generation fails, fall back to a simple format
      "#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%3N%z')} [#{severity}] #{msg} (Error formatting log: #{e.message})\n"
    end

    private

    # Scrub sensitive data from string values in the hash
    def scrub_sensitive_data(data)
      data.each do |key, value|
        if value.is_a?(String)
          # Scrub sensitive information from string values
          data[key] = RailsStructuredLogging::LogstopFork.scrub(value)
        elsif value.is_a?(Hash)
          # Recursively scrub nested hashes
          scrub_sensitive_data(value)
        elsif value.is_a?(Array)
          # Scrub arrays of strings
          data[key] = value.map do |item|
            if item.is_a?(String)
              RailsStructuredLogging::LogstopFork.scrub(item)
            elsif item.is_a?(Hash)
              scrub_sensitive_data(item)
              item
            else
              item
            end
          end
        end
      end
    end

    # Filter sensitive parameters
    def filter_sensitive_params(data)
      # Filter params if present
      if data[:params].is_a?(Hash)
        data[:params] = ParamFilters.filter_params(data[:params])
      end

      # Filter any JSON columns that might contain sensitive data
      ParamFilters.filter_json_columns(data)
    end

    # Generate JSON from the data hash
    def generate_json(data)
      # Use ActiveSupport::JSON.encode for consistent JSON generation
      ActiveSupport::JSON.encode(data)
    end
  end
end
