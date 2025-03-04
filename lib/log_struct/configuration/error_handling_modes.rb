# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class ErrorHandlingModes < T::Struct
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
      
      # Get the appropriate error handling mode for the given source
      sig { params(source: Source).returns(ErrorHandlingMode) }
      def for_source(source)
        case source
        when Source::TypeChecking
          type_checking_errors
        when Source::LogStruct
          logstruct_errors
        when Source::Security
          security_errors
        when Source::Request,
             Source::App,
             Source::Job, 
             Source::Storage,
             Source::Mailer,
             Source::Shrine,
             Source::CarrierWave, 
             Source::Sidekiq
          # All other sources use standard error handling
          standard_errors
        else
          T.absurd(source)
        end
      end
    end
  end
end
