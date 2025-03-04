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
        current_config = LogStruct.config
        T.must(current_config).should_raise?
      when Raise
        true
      else
        T.absurd(self)
      end
    end
  end
end
