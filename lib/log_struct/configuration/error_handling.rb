# typed: strict
# frozen_string_literal: true

module LogStruct
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
    prop :type_errors, ErrorHandlingMode
    prop :logstruct_errors, ErrorHandlingMode
    prop :standard_errors, ErrorHandlingMode

    # Custom handler for exception reporting
    # Default: nil
    prop :exception_reporting_handler, CustomHandlers::ExceptionReporter

    sig { void }
    def initialize
      super(
        type_errors: ErrorHandlingMode::LogProduction,
        logstruct_errors: ErrorHandlingMode::LogProduction,
        standard_errors: ErrorHandlingMode::Raise,
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
