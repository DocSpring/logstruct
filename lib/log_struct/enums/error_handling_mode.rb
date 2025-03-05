# typed: strict
# frozen_string_literal: true

module LogStruct
  # Enum for error handling modes
  class ErrorHandlingMode < T::Enum
    enums do
      # Always ignore the error
      Ignore = new(:ignore)
      # Always log the error
      Log = new(:log)
      # Always report to tracking service and continue
      Report = new(:report)
      # Log in production, raise locally (dev/test)
      LogProduction = new(:log_production)
      # Report in production, raise locally (dev/test)
      ReportProduction = new(:report_production)
      # Always raise regardless of environment
      Raise = new(:raise)
    end
  end
end
