# typed: strict
# frozen_string_literal: true

module LogStruct
  module ConfigStruct
    class ErrorHandlingModes < T::Struct
      include Sorbet::SerializeSymbolKeys

      # How to handle different types of errors
      # Modes:
      # - :ignore - always ignore the error
      # - :log - always log the error
      # - :report - always report to tracking service and continue
      # - :log_production - log in production, raise locally
      # - :report_production - report in production, raise locally
      # - :raise - always raise regardless of environment

      # Configurable error handling categories
      prop :type_checking_errors, ErrorHandlingMode, default: ErrorHandlingMode::LogProduction
      prop :logstruct_errors, ErrorHandlingMode, default: ErrorHandlingMode::LogProduction
      prop :security_errors, ErrorHandlingMode, default: ErrorHandlingMode::Report
      prop :standard_errors, ErrorHandlingMode, default: ErrorHandlingMode::Raise
    end
  end
end
