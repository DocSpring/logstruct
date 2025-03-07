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
          when Source::LogStruct
            config.error_handling_modes.logstruct_errors
          when Source::Security
            config.error_handling_modes.security_errors
          when Source::Rails, Source::App, Source::Job, Source::Storage, Source::Mailer,
               Source::Shrine, Source::CarrierWave, Source::Sidekiq
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
          error_log = Log::Error.from_exception(
            source,
            error,
            context || {}
          )
          LogStruct.log(error_log)
        end

        # Report an error using the configured handler or MultiErrorReporter
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def log_and_report_error(error, source:, context: nil)
          log_error(error, source: source, context: context)
          error_handler = LogStruct.config.error_reporting_handler
          if error_handler
            # Use the configured handler
            error_handler.call(error, context, source)
          else
            # Fall back to MultiErrorReporter (detects Sentry, Bugsnag, etc.)
            LogStruct::MultiErrorReporter.report_error(error, context || {})
          end
        end

        # Handle an error according to the configured error handling mode (log, report, raise, etc)
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def handle_exception(error, source:, context: nil)
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
            log_error(error, source: source, context: context)

          when ErrorHandlingMode::Report, ErrorHandlingMode::ReportProduction
            log_and_report_error(error, source: source, context: context)

          else
            # Ensures the case statement is exhaustive
            T.absurd(mode)
          end
        end
      end
    end
  end
end
