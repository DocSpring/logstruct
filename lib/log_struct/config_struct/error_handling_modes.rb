# typed: strict
# frozen_string_literal: true

module LogStruct
  module ConfigStruct
    class ErrorHandlingModes < T::Struct
      include Sorbet::SerializeSymbolKeys

      # How to handle different types of errors
      # Modes:
      # - Ignore - Ignore the error
      # - Log - Log the error
      # - Report - Log and report to error tracking service (but don't crash)
      # - LogProduction - Log error in production, raise locally (dev/test)
      # - ReportProduction - Report error in production, raise locally (dev/test)
      # - Raise - Always raise the error

      # Configurable error handling categories
      # Sorbet type errors in your app and its gems: logged and reported in production, so they don't pass unseen
      prop :type_checking_errors, ErrorHandlingMode, default: ErrorHandlingMode::ReportProduction
      # LogStruct's own errors
      prop :logstruct_errors, ErrorHandlingMode, default: ErrorHandlingMode::LogProduction
      prop :security_errors, ErrorHandlingMode, default: ErrorHandlingMode::Report
      prop :standard_errors, ErrorHandlingMode, default: ErrorHandlingMode::Raise
    end
  end
end
