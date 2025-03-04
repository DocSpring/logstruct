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
      # Always raise regardless of environment
      RaiseError = new(:raise_error)
    end

    # Check if this mode should raise in the current environment
    sig { returns(T::Boolean) }
    def should_raise?
      case self
      when Ignore, Log, Report
        false
      when LogProduction, ReportProduction
        current_config = LogStruct.config
        current_config.should_raise?
      when Raise, RaiseError
        true
      else
        T.absurd(self)
      end
    end

    sig { params(sym: Symbol).returns(ErrorHandlingMode) }
    def self.from_symbol(sym)
      values.find { |value| value.serialize == sym } ||
        raise(ArgumentError, "Invalid error handling mode: #{sym}")
    end
  end
end
