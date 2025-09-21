# typed: strict
# frozen_string_literal: true

require_relative "enums/error_reporter"
require_relative "handlers"

# Try to require all supported error reporting libraries
# Users may have multiple installed, so we should load all of them
%w[sentry-ruby bugsnag rollbar honeybadger].each do |gem_name|
  require gem_name
rescue LoadError
  # If a particular gem is not available, we'll still load the others
end

module LogStruct
  # MultiErrorReporter provides a unified interface for reporting errors to various services.
  # You can also override this with your own error reporter by setting
  # LogStruct#.config.error_reporting_handler
  # NOTE: This is used for cases where an error should be reported
  # but the operation should be allowed to continue (e.g. scrubbing log data.)
  class MultiErrorReporter
    # Class variable to store the selected reporter
    class CallableReporterWrapper
      extend T::Sig

      sig { params(callable: T.untyped).void }
      def initialize(callable)
        @callable = callable
      end

      sig { returns(T.untyped) }
      attr_reader :callable
      alias_method :original, :callable

      sig { params(error: StandardError, context: T.nilable(T::Hash[Symbol, T.untyped]), source: Source).void }
      def call(error, context, source)
        case callable_arity
        when 3
          callable.call(error, context, source)
        when 2
          callable.call(error, context)
        when 1
          callable.call(error)
        else
          callable.call(error, context, source)
        end
      end

      private

      sig { returns(Integer) }
      def callable_arity
        callable.respond_to?(:arity) ? callable.arity : -1
      end
    end

    ReporterImpl = T.type_alias { T.any(ErrorReporter, CallableReporterWrapper) }

    @reporter_impl = T.let(nil, T.nilable(ReporterImpl))

    class << self
      extend T::Sig

      sig { returns(ReporterImpl) }
      def reporter
        reporter_impl
      end

      # Set the reporter to use (user-friendly API that accepts symbols)
      sig { params(reporter_type: T.any(ErrorReporter, Symbol, Handlers::ErrorReporter)).returns(ReporterImpl) }
      def reporter=(reporter_type)
        @reporter_impl = case reporter_type
        when ErrorReporter
          reporter_type
        when Symbol
          resolve_symbol_reporter(reporter_type)
        else
          wrap_callable_reporter(reporter_type)
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

      # Report an error to the configured error reporting service
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_error(error, context = {})
        # Call the appropriate reporter method based on what's available
        impl = reporter_impl

        case impl
        when ErrorReporter::Sentry
          report_to_sentry(error, context)
        when ErrorReporter::Bugsnag
          report_to_bugsnag(error, context)
        when ErrorReporter::Rollbar
          report_to_rollbar(error, context)
        when ErrorReporter::Honeybadger
          report_to_honeybadger(error, context)
        when ErrorReporter::RailsLogger
          fallback_logging(error, context)
        when CallableReporterWrapper
          impl.call(error, context, Source::Internal)
        end
      end

      private

      sig { returns(ReporterImpl) }
      def reporter_impl
        @reporter_impl ||= detect_reporter
      end

      sig { params(symbol: Symbol).returns(ErrorReporter) }
      def resolve_symbol_reporter(symbol)
        case symbol
        when :sentry then ErrorReporter::Sentry
        when :bugsnag then ErrorReporter::Bugsnag
        when :rollbar then ErrorReporter::Rollbar
        when :honeybadger then ErrorReporter::Honeybadger
        when :rails_logger then ErrorReporter::RailsLogger
        else
          valid_types = ErrorReporter.values.map { |v| ":#{v.serialize}" }.join(", ")
          raise ArgumentError, "Unknown reporter type: #{symbol}. Valid types are: #{valid_types}"
        end
      end

      sig { params(callable: T.untyped).returns(CallableReporterWrapper) }
      def wrap_callable_reporter(callable)
        unless callable.respond_to?(:call)
          raise ArgumentError, "Reporter must respond to #call"
        end

        CallableReporterWrapper.new(callable)
      end

      # Report to Sentry
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_sentry(error, context = {})
        return unless defined?(::Sentry)

        # Use the proper Sentry interface defined in the RBI
        ::Sentry.capture_exception(error, extra: context)
      rescue => e
        fallback_logging(e, {original_error: error.class.to_s})
      end

      # Report to Bugsnag
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_bugsnag(error, context = {})
        return unless defined?(::Bugsnag)

        ::Bugsnag.notify(error) do |report|
          report.add_metadata(:context, context)
        end
      rescue => e
        fallback_logging(e, {original_error: error.class.to_s})
      end

      # Report to Rollbar
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_rollbar(error, context = {})
        return unless defined?(::Rollbar)

        ::Rollbar.error(error, context)
      rescue => e
        fallback_logging(e, {original_error: error.class.to_s})
      end

      # Report to Honeybadger
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def report_to_honeybadger(error, context = {})
        return unless defined?(::Honeybadger)

        ::Honeybadger.notify(error, context: context)
      rescue => e
        fallback_logging(e, {original_error: error.class.to_s})
      end

      # Fallback logging when no error reporting services are available
      # Uses the LogStruct.error method to properly log the error
      sig { params(error: StandardError, context: T::Hash[T.untyped, T.untyped]).void }
      def fallback_logging(error, context = {})
        return if error.nil?

        # Create a proper error log entry
        error_log = Log.from_exception(Source::Internal, error, context)

        # Use LogStruct.error to properly log the error
        LogStruct.error(error_log)
      end
    end
  end
end
