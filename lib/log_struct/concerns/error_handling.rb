# typed: strict
# frozen_string_literal: true

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module ErrorHandling
      module ClassMethods
        extend T::Sig
        extend T::Helpers

        # Needed for raise
        requires_ancestor { Module }

        # Get the error handling mode for a given source
        sig { params(source: Source).returns(ErrorHandlingMode) }
        def error_handling_mode_for(source)
          config = LogStruct.config

          # Use a case statement for type-safety
          case source
          when Source::TypeChecking
            config.error_handling_modes.type_checking_errors
          when Source::Internal
            config.error_handling_modes.logstruct_errors
          when Source::Security
            config.error_handling_modes.security_errors
          when Source::Rails, Source::App, Source::Job, Source::Storage, Source::Mailer,
               Source::Shrine, Source::CarrierWave, Source::Sidekiq, Source::Dotenv, Source::Puma
            config.error_handling_modes.standard_errors
          else
            # Ensures the case statement is exhaustive
            T.absurd(source)
          end
        end

        # Log an errors with structured data
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def log_error(error, source:, context: nil)
          # Create structured log entry
          error_log = Log.from_exception(source, error, context || {})
          LogStruct.error(error_log)
        end

        # Log an error and report it using the configured handler or MultiErrorReporter
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def log_and_report_error(error, source:, context: nil)
          log_error(error, source: source, context: context)
          report_error(error, source: source, context: context)
        end

        # Report an error using the configured handler or MultiErrorReporter, without logging it. A reporter that
        # raises (a timeout calling its service) doesn't change what happens to the error: its own error is logged,
        # and not reported through the same reporter.
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def report_error(error, source:, context: nil)
          context = filtered_context(context)
          error_handler = LogStruct.config.error_reporting_handler
          if error_handler
            # Use the configured handler
            error_handler.call(error, context, source)
          else
            # Fall back to MultiErrorReporter (detects Sentry, Bugsnag, etc.)
            LogStruct::MultiErrorReporter.report_error(error, context || {})
          end
        rescue => e
          LogStruct.error(Log::Error.new(
            source: Source::Internal,
            error_class: e.class,
            message: "The error reporter raised while reporting #{error.class}",
            error_message: e.message,
            backtrace: e.backtrace,
            level: Level::Error
          ))
        end

        # The context filtered and scrubbed like a log line, for error reporters: it can hold a
        # request's parameters or a mail's recipients
        sig { params(context: T.nilable(T::Hash[Symbol, T.untyped])).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
        def filtered_context(context)
          return context if context.nil? || context.empty?

          filtered = Formatter.new.process_values(context)
          filtered.is_a?(Hash) ? filtered : {}
        end

        # Handle an error according to the configured error handling mode (log, report, raise, etc).
        # Pass `log: false` when the caller has already logged the error in its own structured line.
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped]), log: T::Boolean).void }
        def handle_exception(error, source:, context: nil, log: true)
          mode = error_handling_mode_for(source)

          # Log / report in production, raise locally (dev/test)
          if mode == ErrorHandlingMode::LogProduction || mode == ErrorHandlingMode::ReportProduction
            raise(error) if !LogStruct.is_production?
          end

          case mode
          when ErrorHandlingMode::Ignore
            # Do nothing

          when ErrorHandlingMode::Raise
            raise(error)

          when ErrorHandlingMode::Log, ErrorHandlingMode::LogProduction
            log_error(error, source: source, context: context) if log

          when ErrorHandlingMode::Report, ErrorHandlingMode::ReportProduction
            log_error(error, source: source, context: context) if log
            report_error(error, source: source, context: context)

          else
            # Ensures the case statement is exhaustive
            T.absurd(mode)
          end
        end
      end
    end
  end
end
