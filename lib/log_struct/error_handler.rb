# typed: strict
# frozen_string_literal: true

module LogStruct
  # Module for handling errors according to configured modes
  module ErrorHandler
    extend T::Sig

    # Get the error handling mode for a given source
    sig { params(source: ErrorSource).returns(ErrorHandlingMode) }
    def error_handling_mode_for(source)
      config = LogStruct.config
      
      # Map the error source to the appropriate error handling mode
      case source
      when ErrorSource::TypeChecking
        config.error_handling_modes.type_checking_errors
      when ErrorSource::LogStruct
        config.error_handling_modes.logstruct_errors
      when ErrorSource::Security
        config.error_handling_modes.security_errors
      when ErrorSource::Request
        config.error_handling_modes.request_errors
      when ErrorSource::Application
        config.error_handling_modes.application_errors
      else
        # This shouldn't happen if we've defined all possible error sources
        T.absurd(source)
      end
    end

    # Handle an exception according to the configured error handling mode
    sig { params(error: StandardError, source: ErrorSource, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
    def handle_exception(error, source, context = nil)
      mode = error_handling_mode_for(source)

      case mode
      when ErrorHandlingMode::Ignore
        # Do nothing
      when ErrorHandlingMode::Log
        ::Rails.logger.error(error)
      when ErrorHandlingMode::Report
        report_error(error, context, source)
      when ErrorHandlingMode::LogProduction
        if mode.should_raise?
          Kernel.raise(error)
        else
          ::Rails.logger.error(error)
        end
      when ErrorHandlingMode::ReportProduction
        if mode.should_raise?
          Kernel.raise(error)
        else
          report_error(error, context, source)
        end
      when ErrorHandlingMode::Raise, ErrorHandlingMode::RaiseError
        Kernel.raise(error)
      else
        T.absurd(mode)
      end
    end
    
    private
    
    # Report an error using the configured handler or MultiErrorReporter
    sig { params(error: StandardError, context: T.nilable(T::Hash[Symbol, T.untyped]), source: ErrorSource).void }
    def report_error(error, context = nil, source = ErrorSource::Application)
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