# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class TypeSafetyTest < ActiveSupport::TestCase
      def test_basic_typed_logging
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
        LogStruct.log(request_log)

        # Create a typed error log entry
        error_log = LogStruct::Log::Error.new(
          source: LogStruct::Source::App,
          err_class: StandardError,
          message: "An error occurred during processing"
        )

        # Log the error
        LogStruct.log(error_log)
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_typed_logging
        # ----------------------------------------------------------

        # Verify the log objects were created with correct values
        assert_equal "GET", request_log.http_method
        assert_equal "/users", request_log.path
        assert_equal 200, request_log.status
        assert_in_delta(45.2, request_log.duration)
        assert_equal LogStruct::Source::Rails, request_log.source

        assert_equal LogStruct::Source::App, error_log.source
        assert_equal StandardError, error_log.err_class
        assert_equal "An error occurred during processing", error_log.message
      end

      def test_log_enums
        enums = T.let([], T::Array[T.any(LogStruct::LogLevel, LogStruct::Source, LogStruct::ErrorHandlingMode)])
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: log_enums, replace: /enums << /, ""
        # ----------------------------------------------------------
        # Log levels
        enums << LogStruct::LogLevel::Debug
        enums << LogStruct::LogLevel::Info
        enums << LogStruct::LogLevel::Warn
        enums << LogStruct::LogLevel::Error
        enums << LogStruct::LogLevel::Fatal

        # Log sources
        enums << LogStruct::Source::Rails
        enums << LogStruct::Source::App
        enums << LogStruct::Source::Job
        enums << LogStruct::Source::Mailer
        enums << LogStruct::Source::Security
        enums << LogStruct::Source::TypeChecking

        # Error handling modes
        enums << LogStruct::ErrorHandlingMode::Ignore         # Completely ignore errors
        enums << LogStruct::ErrorHandlingMode::Log            # Log errors but don't report them
        enums << LogStruct::ErrorHandlingMode::LogProduction  # Log in production, raise in development
        enums << LogStruct::ErrorHandlingMode::Report         # Log and report errors to error service
        enums << LogStruct::ErrorHandlingMode::Raise          # Always raise errors
        # ----------------------------------------------------------
        # END CODE EXAMPLE: log_enums
        # ----------------------------------------------------------
        # rubocop:enable Lint/Void

        assert_includes(enums, LogStruct::LogLevel::Debug)
        assert_includes(enums, LogStruct::Source::App)
        assert_includes(enums, LogStruct::ErrorHandlingMode::Ignore)
      end

      # Custom log structure must be defined at module level, not inside a method
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: custom_log_structure
      # ----------------------------------------------------------
      # Define a custom log structure
      module TestApp
        module Logs
          class PaymentProcessed < T::Struct
            const :source, Symbol
            const :event, Symbol
            const :timestamp, Time
            const :level,
              LogStruct::LogLevel,
              default: T.let(LogStruct::LogLevel::Info, LogStruct::LogLevel)

            prop :payment_id, String
            prop :amount, Float
            prop :currency, String
            prop :status, String
            prop :user_id, T.nilable(Integer)
          end
        end
      end
      # ----------------------------------------------------------
      # END CODE EXAMPLE: custom_log_structure
      # ----------------------------------------------------------

      def test_custom_log_structure
        # Create a payment log using the class defined above
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

        # Log it
        Rails.logger.info(payment_log)

        # Verify the custom log structure works correctly
        assert_equal :payment_processed, payment_log.source
        assert_equal :payment_processed, payment_log.event
        assert_kind_of Time, payment_log.timestamp
        assert_equal LogStruct::LogLevel::Info, payment_log.level
        assert_equal "pay_123456", payment_log.payment_id
        assert_in_delta(99.99, payment_log.amount)
        assert_equal "USD", payment_log.currency
        assert_equal "succeeded", payment_log.status
        assert_equal 123, payment_log.user_id
      end

      def test_sorbet_error_handler
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

        # Verify the configuration was applied
        refute LogStruct.configuration.integrations.enable_sorbet_error_handlers

        # Reset to true for the rest of the tests
        LogStruct.configure do |config|
          config.integrations.enable_sorbet_error_handlers = true
        end
      end
    end
  end
end
