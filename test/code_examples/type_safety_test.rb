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

        # Log the typed struct at info level
        LogStruct.info(request_log)

        # Create a typed error log entry
        error_log = LogStruct::Log::Error.new(
          source: LogStruct::Source::App,
          err_class: StandardError,
          message: "An error occurred during processing"
        )

        # Log the error at error level
        LogStruct.error(error_log)
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

      # Custom log structure must be defined at module level, not inside a method
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: custom_log_class
      # ----------------------------------------------------------
      # Define a custom log structure
      module TestApp
        class Source < T::Enum
          enums do
            Payments = new
            App = new
          end
        end

        class Event < T::Enum
          enums do
            Processed = new
            Failed = new
          end
        end

        module Log
          class PaymentProcessed < T::Struct
            prop :source, Source
            prop :event, Event
            prop :timestamp, Time, factory: -> { Time.now }

            prop :payment_id, String
            prop :amount, Float
            prop :currency, String
            prop :status, String
            prop :user_id, T.nilable(Integer)
          end
        end
      end

      # ----------------------------------------------------------
      # END CODE EXAMPLE: custom_log_class
      # ----------------------------------------------------------

      def test_custom_log_class
        # Create a payment log using the class defined above
        payment_log = TestApp::Log::PaymentProcessed.new(
          source: TestApp::Source::Payments,
          event: TestApp::Event::Processed,
          timestamp: Time.now,
          payment_id: "pay_123456",
          amount: 99.99,
          currency: "USD",
          status: "succeeded",
          user_id: 123
        )

        # Log it
        Rails.logger.info(payment_log)

        # Verify the custom log structure works correctly
        assert_equal "payments", payment_log.source.serialize
        assert_equal "processed", payment_log.event.serialize
        assert_kind_of Time, payment_log.timestamp
        assert_equal "pay_123456", payment_log.payment_id
        assert_in_delta(99.99, payment_log.amount)
        assert_equal "USD", payment_log.currency
        assert_equal "succeeded", payment_log.status
        assert_equal 123, payment_log.user_id
      end

      def test_disable_sorbet_error_handler
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: test_disable_sorbet_error_handler
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          config.integrations.enable_sorbet_error_handlers = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: test_disable_sorbet_error_handler
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
