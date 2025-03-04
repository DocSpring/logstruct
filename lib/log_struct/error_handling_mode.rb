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
      # Always raise regardless of environment
      RaiseError = new
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
      when Raise
        true
      when RaiseError
        true
      else
        T.absurd(self)
      end
    end

    sig { returns(Symbol) }
    def to_sym
      case self
      when Ignore then :ignore
      when Log then :log
      when Report then :report
      when LogProduction then :log_production
      when ReportProduction then :report_production
      when Raise then :raise
      when RaiseError then :raise_error
      else T.absurd(self)
      end
    end

    sig { params(sym: Symbol).returns(ErrorHandlingMode) }
    def self.from_symbol(sym)
      case sym
      when :ignore then Ignore
      when :log then Log
      when :report then Report
      when :log_production then LogProduction
      when :report_production then ReportProduction
      when :raise then Raise
      when :raise_error then RaiseError
      else
        raise ArgumentError, "Invalid error handling mode: #{sym}"
      end
    end
  end
end
