# typed: strict
# frozen_string_literal: true

module LogStruct
  # Enum for error handling modes
  class ErrorHandlingMode < T::Enum
    enums do
      # Always ignore the error
      Ignore = new
      # Always log the error
      Log = new
      # Always report to tracking service and continue
      Report = new
      # Log in production, raise locally (dev/test)
      LogProduction = new
      # Report in production, raise locally (dev/test)
      ReportProduction = new
      # Always raise regardless of environment
      Raise = new
    end

    # Check if this mode should raise in the current environment
    sig { returns(T::Boolean) }
    def should_raise?
      case self
      when Ignore, Log, Report
        false
      when LogProduction, ReportProduction
        LogStruct.config.should_raise?
      when Raise
        true
      else
        T.absurd(self)
      end
    end

    # Handle the error according to this mode
    sig { params(error: StandardError).void }
    def handle(error)
      case self
      when Ignore
        # Do nothing
      when Log
        ::Rails.logger.error(error)
      when Report
        LogStruct::MultiErrorReporter.report_exception(error)
      when LogProduction
        if should_raise?
          raise error
        else
          ::Rails.logger.error(error)
        end
      when ReportProduction
        if should_raise?
          raise error
        else
          LogStruct::MultiErrorReporter.report_exception(error)
        end
      when Raise
        raise error
      else
        T.absurd(self)
      end
    end
  end
end
