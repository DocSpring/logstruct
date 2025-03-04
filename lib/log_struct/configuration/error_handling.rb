# typed: strict
# frozen_string_literal: true

require_relative "error_handling/mode"

module LogStruct
  class Configuration
    class ErrorHandling < T::Struct
      extend T::Sig

      # How to handle different types of errors
      # Modes:
      # - :ignore - always ignore the error
      # - :log - always log the error
      # - :report - always report to tracking service and continue
      # - :log_production - log in production, raise locally
      # - :report_production - report in production, raise locally
      # - :raise - always raise regardless of environment
      #
      # Default: {
      #   type_errors: :log_production,     # Sorbet type errors - raise in test/dev, log in prod
      #   logstruct_errors: :raise,         # Our own errors - always raise
      #   other_errors: :log               # Everything else - just log
      # }
      prop :type_errors, Mode
      prop :logstruct_errors, Mode
      prop :standard_errors, Mode

      # Custom handler for exception reporting
      # Default: nil
      prop :exception_reporting_handler, LogStruct::CustomHandlers::ExceptionReporter

      sig { void }
      def initialize
        super(
          type_errors: Mode::LogProduction,
          logstruct_errors: Mode::LogProduction,
          standard_errors: Mode::Raise,
          exception_reporting_handler: lambda { |error, context|
            exception_data = LogStruct::Log::Exception.from_exception(
              LogStruct::LogSource::App,
              LogStruct::LogEvent::Error,
              error,
              context
            )
            ::Rails.logger.error(exception_data)
          }
        )
      end
    end
  end
end
