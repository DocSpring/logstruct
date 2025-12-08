# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class LoggingTest < ActiveSupport::TestCase
      class MockUser < T::Struct
        const :id, Integer
        const :email, String
      end

      class MockRequest < T::Struct
        const :remote_ip, String
      end

      def setup
        @original_logger = Rails.logger
      end

      def teardown
        Rails.logger = @original_logger
      end

      def test_basic_logging
        user = MockUser.new(id: 123, email: "user@example.com")
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------
        # Log a simple string
        Rails.logger.info "User signed in"

        # Log a hash with custom fields
        Rails.logger.info({
          event: "user_login",
          user_id: user.id,
          ip_address: "192.168.1.1",
          custom_field: "any value you want"
        })
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------
        assert_equal 123, user.id # Stop minitest complaining
      end

      def test_getting_started_basic_logging
        user = MockUser.new(id: 123, email: "user@example.com")
        request = MockRequest.new(remote_ip: "192.168.1.1")

        # Set up tagged logger
        Rails.logger = ActiveSupport::TaggedLogging.new(Rails.logger)

        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------
        # Log a simple message
        Rails.logger.info "User signed in"

        # Log structured data
        Rails.logger.info({
          src: "rails",
          evt: "user_login",
          user_id: user.id,
          ip_address: request.remote_ip
        })

        # Log with tags
        Rails.logger.tagged("Authentication") do
          Rails.logger.info "User signed in"
          Rails.logger.info(user_id: user.id, ip_address: request.remote_ip)
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------
        assert_equal 123, user.id # Stop minitest complaining
      end

      def test_typed_logging
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: typed_logging
        # ----------------------------------------------------------
        # Create a typed log entry
        log = LogStruct::Log::Plain.new(
          source: LogStruct::Source::App,
          message: "User signed in",
          additional_data: {
            user_id: 123,
            ip_address: "192.168.1.1"
          }
        )

        # Log the typed struct
        LogStruct.info(log)
        # ----------------------------------------------------------
        # END CODE EXAMPLE: typed_logging
        # ----------------------------------------------------------

        # Simple assertion to make the test pass
        assert_instance_of LogStruct::Log::Plain, log
      end
    end
  end
end
