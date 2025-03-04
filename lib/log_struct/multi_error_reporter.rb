# typed: strict
# frozen_string_literal: true

require_relative "enums/error_reporter"

%w[sentry-ruby bugsnag rollbar honeybadger].any? do |gem_name|
  require gem_name
  true
rescue LoadError
  # If none of these gems are not available we'll fall back to Rails.logger
end

module LogStruct
  # MultiErrorReporter provides a unified interface for reporting errors to various services.
  # You can also override this with your own error reporter by setting
  # LogStruct#.config.exception_reporting_handler
  # NOTE: This is used for cases where an error should be reported
  # but the operation should be allowed to continue (e.g. scrubbing log data.)
  class MultiErrorReporter
    # Use T.let to properly declare the class variable at the class level
    @error_reporter = T.let(ErrorReporter::RailsLogger, ErrorReporter)

    class << self
      extend T::Sig

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
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_exception(exception, context = {})
        # Initialize reporter if it hasn't been done
        initialize_reporter if @error_reporter.nil?

        # Call the appropriate reporter method based on what's available
        case @error_reporter
        when ErrorReporter::Sentry
          report_to_sentry(exception, context)
        when ErrorReporter::Bugsnag
          report_to_bugsnag(exception, context)
        when ErrorReporter::Rollbar
          report_to_rollbar(exception, context)
        when ErrorReporter::Honeybadger
          report_to_honeybadger(exception, context)
        else
          fallback_logging(exception, context)
        end
      end

      private

      # Report to Sentry
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_sentry(exception, context = {})
        return unless defined?(::Sentry)

        # Use the proper Sentry interface defined in the RBI
        ::Sentry.capture_exception(exception, extra: context)
      rescue => e
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Bugsnag
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_bugsnag(exception, context = {})
        return unless defined?(::Bugsnag)

        ::Bugsnag.notify(exception) do |report|
          report.add_metadata(:context, context)
        end
      rescue => e
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Rollbar
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_rollbar(exception, context = {})
        return unless defined?(::Rollbar)

        ::Rollbar.error(exception, context)
      rescue => e
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Report to Honeybadger
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_honeybadger(exception, context = {})
        return unless defined?(::Honeybadger)

        ::Honeybadger.notify(exception, context: context)
      rescue => e
        fallback_logging(e, {original_exception: exception.class.to_s})
      end

      # Fallback logging when no error reporting services are available
      # Uses the LogStruct.log method to properly log the exception
      sig { params(exception: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def fallback_logging(exception, context = {})
        return if exception.nil?

        # Create a proper exception log entry
        exception_log = Log::Exception.from_exception(
          Source::LogStruct,
          exception,
          context
        )

        # Use LogStruct.log to properly log the exception
        LogStruct.log(exception_log)
      end
    end

    # Initialize the reporter when the class is loaded
    initialize_reporter
  end
end
