# typed: strict
# frozen_string_literal: true

require_relative "error_reporter"

%w[sentry-ruby bugsnag rollbar honeybadger].any? do |gem_name|
  require gem_name
  true
rescue LoadError
  # If none of these gems are not available we'll fall back to Rails.logger
end

# MultiErrorReporter provides a unified interface for reporting errors to various services.
# You can also configure your own error reporter by setting LogStruct.config.exception_reporting_handler.
# NOTE: This is used for cases where an error should be reported
# but the operation should be allowed to continue (e.g. scrubbing log data.)
module LogStruct
  class MultiErrorReporter
    # Use T.let to properly declare the class variable at the class level
    @error_reporter = T.let(ErrorReporter::RailsLogger, ErrorReporter)

    class << self
      sig { returns(ErrorReporter) }
      attr_reader :error_reporter

      # Initialize the error reporter once
      sig { returns(ErrorReporter) }
      def initialize_reporter
        @error_reporter = if defined?(::Sentry)
          ErrorReporter::Sentry
        elsif defined?(::Bugsnag)
          ErrorReporter::Bugsnag
        elsif defined?(::Rollbar)
          ErrorReporter::Rollbar
        elsif defined?(::Honeybadger)
          ErrorReporter::Honeybadger
        else
          ErrorReporter::RailsLogger
        end
      end

      # Report an exception to the configured error reporting service
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_exception(exception, context = {})
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
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Rollbar
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_rollbar(exception, context = {})
        return unless defined?(::Rollbar)

        ::Rollbar.error(exception, context)
      rescue => e
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Honeybadger
      sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_honeybadger(exception, context = {})
        return unless defined?(::Honeybadger)

        ::Honeybadger.notify(exception, context: context)
      rescue => e
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
