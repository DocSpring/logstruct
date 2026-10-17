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

      setup do
        ::SemanticLogger.flush
        # Only the lines the example logs, not those logged as the test started
        @log_offset = TEST_LOG_IO.string.bytesize
      end

      def test_basic_logging
        user = MockUser.new(id: 123, email: "user@example.com")
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------
        # Log a message
        Rails.logger.info "User signed in"

        # Log a Hash: its keys become the line's fields, and evt names the event
        Rails.logger.info({evt: "user_login", user_id: user.id, plan: "pro"})

        # Log a message with fields
        Rails.logger.info({msg: "Charged the card", amount_cents: 1999, currency: "usd"})
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------

        message, hash, message_with_fields = logged_lines

        assert_equal({"src" => "app", "evt" => "log", "lvl" => "info", "msg" => "User signed in"}, message.except("ts", "prog"))
        assert_equal({"src" => "app", "evt" => "user_login", "lvl" => "info", "user_id" => 123, "plan" => "pro"}, hash.except("ts", "prog"))
        assert_equal ["Charged the card", 1999, "usd"], message_with_fields.values_at("msg", "amount_cents", "currency")
      end

      def test_getting_started_basic_logging
        user = MockUser.new(id: 123, email: "user@example.com")

        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------
        # Log a message
        Rails.logger.info "User signed in"

        # Log a Hash of fields
        Rails.logger.info({evt: "user_login", user_id: user.id, email: user.email})

        # Tag every line logged in a block
        Rails.logger.tagged("Authentication") do
          Rails.logger.info "Checking the password"
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------

        message, hash, tagged = logged_lines

        assert_equal "User signed in", message["msg"]
        assert_equal ["user_login", 123], hash.values_at("evt", "user_id")
        # The email key is filtered, with a hash of the address so lines about the same person can be found
        assert_equal ["String"], [hash.dig("email", "_filtered", "_class")]
        assert_match(/\A\h{12}\z/, hash.dig("email", "_filtered", "_hash"))
        assert_equal [["Authentication"], "Checking the password"], tagged.values_at("tags", "msg")
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
            plan: "pro"
          }
        )

        # Log the typed struct
        LogStruct.info(log)
        # ----------------------------------------------------------
        # END CODE EXAMPLE: typed_logging
        # ----------------------------------------------------------

        line = logged_lines.last

        assert_equal(
          {"src" => "app", "evt" => "log", "lvl" => "info", "msg" => "User signed in", "user_id" => 123, "plan" => "pro"},
          line.except("ts", "prog")
        )
      end

      private

      def logged_lines
        ::SemanticLogger.flush
        T.must(TEST_LOG_IO.string.byteslice(@log_offset..)).lines.map { |line| JSON.parse(line) }
      end
    end
  end
end
