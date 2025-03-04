# typed: strict
# frozen_string_literal: true

module LogStruct
  # Module for handling errors according to configured modes
  module ErrorHandler
    extend T::Sig

    # Get the error handling mode for a given source
    sig { params(source: Source).returns(ErrorHandlingMode) }
    def error_handling_mode_for(source)
      config = LogStruct.config

      # Map the error source to the appropriate error handling mode
      case source
      when Source::TypeChecking
        config.error_handling_modes.type_checking_errors
      when Source::LogStruct
        config.error_handling_modes.logstruct_errors
      when Source::Security
        config.error_handling_modes.security_errors
      when Source::Request
        config.error_handling_modes.request_errors
      when Source::App
        config.error_handling_modes.application_errors
      else
        # This shouldn't happen if we've defined all possible error sources
        T.absurd(source)
      end
    end

    # Create an exception log entry
    sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).returns(Log::Exception) }
    def log_exception(error, source:, context: nil)
      Log::Exception.from_exception(
        source,
        LogEvent::Error,
        error,
        context || {}
      )
    end

    # Handle an exception according to the configured error handling mode
    sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
    def handle_exception(error, source:, context: nil)
      mode = error_handling_mode_for(source)

      case mode
      when ErrorHandlingMode::Ignore
        # Do nothing
      when ErrorHandlingMode::Log
        # Log the exception with structured data
        exception_log = log_exception(error, source: source, context: context)
        ::Rails.logger.error(exception_log.to_json)
      when ErrorHandlingMode::Report
        report_exception(error, source: source, context: context)
      when ErrorHandlingMode::LogProduction
        if mode.should_raise?
          Kernel.raise(error)
        else
          exception_log = log_exception(error, source: source, context: context)
          ::Rails.logger.error(exception_log.to_json)
        end
      when ErrorHandlingMode::ReportProduction
        if mode.should_raise?
          Kernel.raise(error)
        else
          report_exception(error, source: source, context: context)
        end
      when ErrorHandlingMode::Raise, ErrorHandlingMode::RaiseError
        Kernel.raise(error)
      else
        T.absurd(mode)
      end
    end

    private

    # Report an exception using the configured handler or MultiErrorReporter
    sig { params(error: StandardError, source: Source, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
    def report_exception(error, source:, context: nil)
      if LogStruct.config.exception_reporting_handler
        # Use the configured handler
        LogStruct.config.exception_reporting_handler.call(error, context, source)
      else
        # Fall back to MultiErrorReporter
        LogStruct::MultiErrorReporter.report_exception(error, context)
      end
    end
  end
end
