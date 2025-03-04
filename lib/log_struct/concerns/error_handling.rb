# typed: strict
# frozen_string_literal: true

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module ErrorHandling
      extend T::Sig

      # Get the error handling mode for a given source
      sig { params(source: ErrorSource).returns(ErrorHandlingMode) }
      def error_handling_mode_for(source)
        config = LogStruct.config
        
        # Use a case statement for type-safety instead of dynamic dispatch
        case source
        when ErrorSource::TypeCheck
          config.error_handling.type_errors
        when ErrorSource::LogStruct
          config.error_handling.logstruct_errors
        else
          # All other errors use the standard error mode
          config.error_handling.standard_errors
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
          # Use the configured handler if available, fall back to MultiErrorReporter
          report_error(error, context)
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
            report_error(error, context)
          end
        when ErrorHandlingMode::Raise
          Kernel.raise(error)
        else
          T.absurd(mode)
        end
      end
      
      private
      
      # Report an error using the configured handler or MultiErrorReporter
      sig { params(error: StandardError, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
      def report_error(error, context = nil)
        if LogStruct.config.exception_reporting_handler
          # Use the configured handler
          LogStruct.config.exception_reporting_handler.call(error, context)
        else
          # Fall back to MultiErrorReporter
          LogStruct::MultiErrorReporter.report_exception(error, context)
        end
      end
    end
  end
end