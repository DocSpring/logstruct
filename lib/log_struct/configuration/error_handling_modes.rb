# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class ErrorHandlingModes < T::Struct
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
      # Errors are categorized by source:
      # - type_checking_errors: Errors from type checking (Sorbet, etc)
      # - logstruct_errors: Errors from LogStruct itself (e.g. scrubbing, filtering, JSON formatting)
      # - security_errors: Security-related errors (CSRF, IP spoofing)
      # - request_errors: Errors from request handling
      # - application_errors: Application errors that don't fit into other categories
      
      prop :type_checking_errors, LogStruct::ErrorHandlingMode
      prop :logstruct_errors, LogStruct::ErrorHandlingMode
      prop :security_errors, LogStruct::ErrorHandlingMode
      prop :request_errors, LogStruct::ErrorHandlingMode
      prop :application_errors, LogStruct::ErrorHandlingMode

      sig { void }
      def initialize
        super(
          type_checking_errors: LogStruct::ErrorHandlingMode::LogProduction,
          logstruct_errors: LogStruct::ErrorHandlingMode::LogProduction,
          security_errors: LogStruct::ErrorHandlingMode::Report,
          request_errors: LogStruct::ErrorHandlingMode::Log,
          application_errors: LogStruct::ErrorHandlingMode::Raise
        )
      end
      
      # Get the appropriate error handling mode for the given error source
      sig { params(source: LogStruct::ErrorSource).returns(LogStruct::ErrorHandlingMode) }
      def for_source(source)
        case source
        when LogStruct::ErrorSource::TypeChecking
          type_checking_errors
        when LogStruct::ErrorSource::LogStruct
          logstruct_errors
        when LogStruct::ErrorSource::Security
          security_errors
        when LogStruct::ErrorSource::Request
          request_errors
        when LogStruct::ErrorSource::Application
          application_errors
        else
          T.absurd(source)
        end
      end
    end
  end
end