# typed: strict
# frozen_string_literal: true

module LogStruct
  # Module for handling errors according to configured modes
  module ErrorHandler
    extend T::Sig

    # Handle an exception according to the configured error handling mode
    sig { params(error: StandardError, source: ErrorSource, context: T.nilable(T::Hash[Symbol, T.untyped])).void }
    def handle_exception(error, source, context = nil)
      current_config = LogStruct.config
      mode = T.must(current_config).mode_for(source.serialize.to_sym)

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
