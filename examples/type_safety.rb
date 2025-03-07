# typed: strict
# frozen_string_literal: true

require "log_struct"

# Examples demonstrating LogStruct's type safety features
module Examples
  extend T::Sig

  sig { void }
  def self.type_safety_examples
    # ----------------------------------------------------------
    # BEGIN CODE EXAMPLE: basic_typed_logging
    # ----------------------------------------------------------
    # Create a typed request log entry
    request_log = LogStruct::Log::Request.new(
      http_method: "GET",
      path: "/users",
      status: 200,
      duration: 45.2,
      source: LogStruct::Source::Rails
    )

    # Log the typed struct
    Rails.logger.info(request_log)

    # Create a typed error log entry
    error_log = LogStruct::Log::Error.new(
      source: LogStruct::Source::App,
      err_class: StandardError,
      message: "An error occurred during processing"
    )

    # Log the error
    Rails.logger.error(error_log)
    # ----------------------------------------------------------
    # END CODE EXAMPLE: basic_typed_logging
    # ----------------------------------------------------------

    # rubocop:disable Lint/Void
    # ----------------------------------------------------------
    # BEGIN CODE EXAMPLE: log_enums
    # ----------------------------------------------------------
    # Log levels
    LogStruct::LogLevel::Debug
    LogStruct::LogLevel::Info
    LogStruct::LogLevel::Warn
    LogStruct::LogLevel::Error
    LogStruct::LogLevel::Fatal

    # Log sources
    LogStruct::Source::Rails
    LogStruct::Source::App
    LogStruct::Source::Job
    LogStruct::Source::Mailer
    LogStruct::Source::Security
    LogStruct::Source::TypeChecking

    # Error handling modes
    LogStruct::ErrorHandlingMode::Ignore         # Completely ignore errors
    LogStruct::ErrorHandlingMode::Log            # Log errors but don't report them
    LogStruct::ErrorHandlingMode::LogProduction  # Log in production, raise in development
    LogStruct::ErrorHandlingMode::Report         # Log and report errors to error service
    LogStruct::ErrorHandlingMode::Raise          # Always raise errors
    # ----------------------------------------------------------
    # END CODE EXAMPLE: log_enums
    # ----------------------------------------------------------
    # rubocop:enable Lint/Void
  end

  # ----------------------------------------------------------
  # BEGIN CODE EXAMPLE: custom_log_structure
  # ----------------------------------------------------------
  # Define a custom log structure
  module TestApp
    module Logs
      class PaymentProcessed < T::Struct
        const :source, Symbol, name: :src
        const :event, Symbol, name: :evt
        const :timestamp, Time, name: :ts
        const :level,
          LogStruct::LogLevel,
          name: :lvl,
          default: T.let(LogStruct::LogLevel::Info, LogStruct::LogLevel)

        prop :payment_id, String
        prop :amount, Float
        prop :currency, String
        prop :status, String
        prop :user_id, T.nilable(Integer)
      end
    end
  end

  # Then use it in your code
  payment_log = TestApp::Logs::PaymentProcessed.new(
    source: :payment_processed,
    event: :payment_processed,
    timestamp: Time.now,
    level: LogStruct::LogLevel::Info,
    payment_id: "pay_123456",
    amount: 99.99,
    currency: "USD",
    status: "succeeded",
    user_id: 123
  )

  Rails.logger.info(payment_log)
  # ----------------------------------------------------------
  # END CODE EXAMPLE: custom_log_structure
  # ----------------------------------------------------------

  # ----------------------------------------------------------
  # BEGIN CODE EXAMPLE: sorbet_error_handler
  # ----------------------------------------------------------
  # In development and test environments, type errors will raise exceptions
  # In production, type errors will be logged but won't crash your application

  # The Sorbet error handlers are enabled by default. If you already use Sorbet
  # in your app and you define your own handlers, you can disable LogStruct handlers:
  LogStruct.configure do |config|
    config.integrations.enable_sorbet_error_handlers = false
  end
  # ----------------------------------------------------------
  # END CODE EXAMPLE: sorbet_error_handler
  # ----------------------------------------------------------
end
