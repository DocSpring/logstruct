# typed: strict
# frozen_string_literal: true

require "json"

%w[sentry-ruby bugsnag rollbar honeybadger].each do |gem|
  require gem
rescue LoadError
  # If none of these gems are not available we'll fall back to Rails.logger
end

module RailsStructuredLogging
  # MultiErrorReporter provides a unified interface for reporting errors to various services
  # It automatically detects and uses available error reporting services
  # Similar to MultiJSON, it detects available adapters once and then uses the configured one
  class MultiErrorReporter
    # Use T.let to properly declare the class variable at the class level
    @error_reporter = T.let(Enums::ErrorTracker::Logger, Enums::ErrorTracker)

    class << self
      sig { returns(Enums::ErrorTracker) }
      attr_reader :error_reporter

      # Initialize the error reporter once
      sig { returns(Enums::ErrorTracker) }
      def initialize_reporter
        @error_reporter = if defined?(::Sentry)
          Enums::ErrorTracker::Sentry
        elsif defined?(::Bugsnag)
          Enums::ErrorTracker::Bugsnag
        elsif defined?(::Rollbar)
          Enums::ErrorTracker::Rollbar
        elsif defined?(::Honeybadger)
          Enums::ErrorTracker::Honeybadger
        else
          Enums::ErrorTracker::Logger
        end
      end

      # Report an exception to the configured error reporting service
      # @param exception [Exception] The exception to report
      # @param context [Hash] Additional context to include with the error report
      # @return [void]
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_exception(exception, context = {})
        # Initialize the reporter if it hasn't been initialized yet
        @error_reporter ||= initialize_reporter

        # Call the appropriate reporter method based on what's available
        case @error_reporter
        when :sentry
          report_to_sentry(exception, context)
        when :bugsnag
          report_to_bugsnag(exception, context)
        when :rollbar
          report_to_rollbar(exception, context)
        when :honeybadger
          report_to_honeybadger(exception, context)
        else
          fallback_logging(exception, context)
        end
      end

      private

      # Report to Sentry
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_sentry(exception, context = {})
        return unless defined?(::Sentry)

        # Use the proper Sentry interface defined in the RBI
        ::Sentry.capture_exception(exception, extra: context)
      rescue => e
        # If Sentry fails, fall back to basic logging
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Bugsnag
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_bugsnag(exception, context = {})
        return unless defined?(::Bugsnag)

        ::Bugsnag.notify(exception) do |report|
          report.add_metadata(:context, context)
        end
      rescue => e
        # If Bugsnag fails, fall back to basic logging
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Rollbar
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_rollbar(exception, context = {})
        return unless defined?(::Rollbar)

        ::Rollbar.error(exception, context)
      rescue => e
        # If Rollbar fails, fall back to basic logging
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Honeybadger
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_honeybadger(exception, context = {})
        return unless defined?(::Honeybadger)

        ::Honeybadger.notify(exception, context: context)
      rescue => e
        # If Honeybadger fails, fall back to basic logging
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Fallback logging when no error reporting services are available
      # Writes directly to stdout to avoid potential infinite loops with Rails.logger
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def fallback_logging(exception, context = {})
        return if exception.nil?

        # Create a structured log entry
        log_data = {
          src: "rails",
          evt: "error",
          error_class: exception.class.to_s,
          error_message: exception.message,
          backtrace: exception.backtrace&.take(20)
        }

        # Add context if provided
        log_data[:context] = context if context.any?

        # Write directly to stdout to avoid potential infinite loops
        # (the log formatter uses this method itself to report errors)
        $stdout.puts log_data.to_json
      end
    end

    # Initialize the reporter when the class is loaded
    initialize_reporter
  end
end
