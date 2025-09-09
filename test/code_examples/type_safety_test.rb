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
          duration_ms: 45.2,
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
        assert_in_delta(45.2, request_log.duration_ms)
        assert_equal LogStruct::Source::Rails, request_log.source

        assert_equal LogStruct::Source::App, error_log.source
        assert_equal StandardError, error_log.err_class
        assert_equal "An error occurred during processing", error_log.message
      end

      # Custom log structure must be defined at module level, not inside a method
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: custom_log_class
      # ----------------------------------------------------------
      # Define a custom typed log using LogStruct interfaces
      module TestApp
        module Log
          class Payments < T::Struct
            extend T::Sig

            include ::LogStruct::Log::Interfaces::PublicCommonFields
            include ::LogStruct::Log::Interfaces::AdditionalDataField
            include ::LogStruct::Log::SerializeCommonPublic
            include ::LogStruct::Log::MergeAdditionalDataFields

            # Event restricted to a specific set for type safety (T::Enum)
            class Event < T::Enum
              enums do
                Processed = new(:processed)
                Failed = new(:failed)
                Refunded = new(:refunded)
              end
            end

            # Fixed source: not overridable by callers
            sig { returns(String) }
            def source = "payments"

            const :event, Event
            const :level, ::LogStruct::Level, default: T.let(::LogStruct::Level::Info, ::LogStruct::Level)
            const :timestamp, Time, factory: -> { Time.now }

            # Domain fields
            const :payment_id, String
            const :amount_cents, Integer
            const :currency, String
            const :status, String
            const :user_id, T.nilable(Integer), default: nil

            # Optional extra data merged at top-level
            const :additional_data, T::Hash[Symbol, T.untyped], default: {}

            sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
            def serialize(strict = true)
              h = serialize_common_public(strict)
              merge_additional_data_fields(h)
              h[:payment_id] = payment_id
              h[:amount_cents] = amount_cents
              h[:currency] = currency
              h[:status] = status
              h[:user_id] = user_id if user_id
              h
            end
          end
        end
      end

      # ----------------------------------------------------------
      # END CODE EXAMPLE: custom_log_class
      # ----------------------------------------------------------

      def test_custom_log_class
        # Create a payment log using the class defined above
        payment_log = TestApp::Log::Payments.new(
          event: TestApp::Log::Payments::Event::Processed,
          payment_id: "pay_123456",
          amount_cents: 9999,
          currency: "USD",
          status: "succeeded",
          user_id: 123
        )

        # Log it
        Rails.logger.info(payment_log)

        # Verify the custom log structure works correctly
        json = payment_log.as_json

        assert_equal "payments", json["src"]
        # Enum serializes to string via SerializeCommonPublic
        assert_equal "processed", json["evt"]
        assert_equal "pay_123456", json["payment_id"]
        assert_equal 9999, json["amount_cents"]
        assert_equal "USD", json["currency"]
        assert_equal "succeeded", json["status"]
        assert_equal 123, json["user_id"]
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
