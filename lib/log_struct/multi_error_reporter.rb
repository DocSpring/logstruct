# typed: strict
# frozen_string_literal: true

require_relative "enums/error_reporter"

%w[sentry-ruby bugsnag rollbar honeybadger].any? do |gem_name|
  require gem_name
  true
rescue LoadError
  # If none of these gems are available we'll fall back to Rails.logger
end

module LogStruct
  # MultiErrorReporter provides a unified interface for reporting errors to various services.
  # You can also override this with your own error reporter by setting
  # LogStruct#.config.exception_reporting_handler
  # NOTE: This is used for cases where an error should be reported
  # but the operation should be allowed to continue (e.g. scrubbing log data.)
  class MultiErrorReporter
    # Class variable to store the selected reporter
    @reporter = T.let(nil, T.nilable(ErrorReporter))

    class << self
      extend T::Sig

      sig { returns(ErrorReporter) }
      def reporter
        @reporter ||= detect_reporter
      end

      # Set the reporter to use (user-friendly API that accepts symbols)
      sig { params(reporter_type: T.any(ErrorReporter, Symbol)).returns(ErrorReporter) }
      def reporter=(reporter_type)
        @reporter = case reporter_type
        when ErrorReporter
          reporter_type
        when Symbol
          case reporter_type
          when :sentry then ErrorReporter::Sentry
          when :bugsnag then ErrorReporter::Bugsnag
          when :rollbar then ErrorReporter::Rollbar
          when :honeybadger then ErrorReporter::Honeybadger
          when :rails_logger then ErrorReporter::RailsLogger
          else
            valid_types = ErrorReporter.values.map { |v| ":#{v.serialize}" }.join(", ")
            raise ArgumentError, "Unknown reporter type: #{reporter_type}. Valid types are: #{valid_types}"
          end
        end
      end

      # Auto-detect which error reporting service to use
      sig { returns(ErrorReporter) }
      def detect_reporter
        if defined?(::Sentry)
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
        # Call the appropriate reporter method based on what's available
        case reporter
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
  end
end
