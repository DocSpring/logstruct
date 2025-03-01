# frozen_string_literal: true

module RailsStructuredLogging
  # MultiErrorReporter provides a unified interface for reporting errors to various services
  # It automatically detects and uses available error reporting services
  # Similar to MultiJSON, it detects available adapters once and then uses the configured one
  class MultiErrorReporter
    class << self
      attr_reader :error_reporter

      # Initialize the error reporter once
      def initialize_reporter
        if defined?(Sentry)
          @error_reporter = :sentry
        elsif defined?(Bugsnag)
          @error_reporter = :bugsnag
        elsif defined?(Rollbar)
          @error_reporter = :rollbar
        elsif defined?(Honeybadger)
          @error_reporter = :honeybadger
        else
          @error_reporter = :fallback
        end
      end

      # Report an exception to the configured error reporting service
      # @param exception [Exception] The exception to report
      # @param context [Hash] Additional context to include with the error report
      # @return [void]
      def report_exception(exception, context = {})
        return if exception.nil?

        # Initialize the reporter if it hasn't been initialized yet
        initialize_reporter unless @error_reporter

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
      def report_to_sentry(exception, context = {})
        Sentry.capture_exception(exception, extra: context)
      rescue => e
        # If Sentry fails, fall back to basic logging
        fallback_logging(e, { original_exception: exception.class.name })
      end

      # Report to Bugsnag
      def report_to_bugsnag(exception, context = {})
        Bugsnag.notify(exception) do |report|
          report.add_metadata(:context, context)
        end
      rescue => e
        # If Bugsnag fails, fall back to basic logging
        fallback_logging(e, { original_exception: exception.class.name })
      end

      # Report to Rollbar
      def report_to_rollbar(exception, context = {})
        Rollbar.error(exception, context)
      rescue => e
        # If Rollbar fails, fall back to basic logging
        fallback_logging(e, { original_exception: exception.class.name })
      end

      # Report to Honeybadger
      def report_to_honeybadger(exception, context = {})
        Honeybadger.notify(exception, context: context)
      rescue => e
        # If Honeybadger fails, fall back to basic logging
        fallback_logging(e, { original_exception: exception.class.name })
      end

      # Fallback logging when no error reporting services are available
      # Writes directly to stdout to avoid potential infinite loops with Rails.logger
      def fallback_logging(exception, context = {})
        return if exception.nil?

        # Create a structured log entry
        log_data = {
          src: 'rails',
          evt: 'error',
          error_class: exception.class.name,
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
