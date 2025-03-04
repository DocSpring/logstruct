# typed: strict
# frozen_string_literal: true

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module ErrorHandling
      module ClassMethods
        extend T::Sig
        extend T::Helpers

        # Needed for #raise
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
          when Source::Request,
               Source::App,
               Source::Job,
               Source::Storage,
               Source::Mailer,
               Source::Shrine,
               Source::CarrierWave,
               Source::Sidekiq
            config.error_handling_modes.standard_errors
          else
            # This shouldn't happen if we've defined all possible error sources
            T.absurd(source)
          end
        end

        # Log an exception with structured data
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def log_exception(error, source:, context: nil)
          # Create structured log entry
          exception_log = Log::Exception.from_exception(
            source,
            LogEvent::Error,
            error,
            context || {}
          )

          # Use the structured log entry directly with Rails logger
          # The JSONFormatter will handle proper serialization
          ::Rails.logger.error(exception_log)
        end

        # Report an exception using the configured handler or MultiErrorReporter
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def report_exception(error, source:, context: nil)
          exception_handler = LogStruct.config.exception_reporting_handler
          if exception_handler
            # Use the configured handler
            exception_handler.call(error, context, source)
          else
            # Fall back to MultiErrorReporter
            LogStruct::MultiErrorReporter.report_exception(error, context || {})
          end
        end

        # Handle an exception according to the configured error handling mode (log, report, raise, etc)
        sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
        def handle_exception(error, source:, context: nil)
          mode = error_handling_mode_for(source)

          case mode
          when ErrorHandlingMode::Ignore
            # Do nothing
          when ErrorHandlingMode::Log
            log_exception(error, source: source, context: context)
          when ErrorHandlingMode::Report
            report_exception(error, source: source, context: context)
          when ErrorHandlingMode::LogProduction
            if mode.should_raise?
              raise(error)
            else
              log_exception(error, source: source, context: context)
            end
          when ErrorHandlingMode::ReportProduction
            if mode.should_raise?
              raise(error)
            else
              report_exception(error, source: source, context: context)
            end
          when ErrorHandlingMode::Raise, ErrorHandlingMode::RaiseError
            raise(error)
          else
            T.absurd(mode)
          end
        end
      end
    end
  end
end
