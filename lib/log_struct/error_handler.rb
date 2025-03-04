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
      mode = config.error_handling[source.serialize.to_sym]
      return mode if mode.is_a?(ErrorHandlingMode)
      standard_mode = config.error_handling[:standard_errors]
      raise "No standard error handling mode configured" unless standard_mode.is_a?(ErrorHandlingMode)
      standard_mode
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
        LogStruct::MultiErrorReporter.report_exception(error)
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
          LogStruct::MultiErrorReporter.report_exception(error)
        end
      when ErrorHandlingMode::Raise
        Kernel.raise(error)
      else
        T.absurd(mode)
      end
    end
  end
end
