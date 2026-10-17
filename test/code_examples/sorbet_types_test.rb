# typed: true
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
# The custom_log_class example (TestApp::Log::Payments)
require_relative "type_safety_test"

module LogStruct
  module CodeExamples
    # The examples on the docs' Sorbet Types page. The page's example lines are read from the page and
    # checked against what LogStruct writes: docs/app/docs/sorbet-types/page.tsx
    class SorbetTypesTest < ActiveSupport::TestCase
      include DocsPage

      PAGE = File.expand_path("../../docs/app/docs/sorbet-types/page.tsx", __dir__)

      # A server whose time zone is UTC
      TIME = Time.new(2026, 10, 17, 9, 30, 15.123r, "+00:00")

      # The page's examples name the custom log class from type_safety_test.rb
      TestApp = TypeSafetyTest::TestApp

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: sorbet_typed_method
      # ----------------------------------------------------------
      class Greeter
        extend T::Sig

        sig { params(name: String).returns(String) }
        def self.greet(name) = "Hello, #{name}"
      end
      # ----------------------------------------------------------
      # END CODE EXAMPLE: sorbet_typed_method
      # ----------------------------------------------------------

      setup do
        @io = setup_isolated_logger
        # The default hash length, and a key that isn't the test app's
        LogStruct.config.filters.hash_length = 16
        LogStruct.config.filters.hash_salt = "logstruct-docs-example"
        @saved_handlers = SORBET_HANDLERS.to_h { |name| [name, T::Configuration.instance_variable_get(:"@#{name}")] }
        LogStruct::Integrations::Sorbet.setup(LogStruct.config)
      end

      teardown do
        @saved_handlers.each { |name, handler| T::Configuration.send(:"#{name}=", handler) }
        teardown_isolated_logger
      end

      SORBET_HANDLERS = %i[
        inline_type_error_handler
        call_validation_error_handler
        sig_builder_error_handler
        sig_validation_error_handler
      ].freeze

      def test_type_errors_raise_in_development_and_test
        refute_predicate LogStruct, :is_production?
        assert_equal ErrorHandlingMode::ReportProduction, LogStruct.config.error_handling_modes.type_checking_errors

        error = assert_raises(TypeError) { Greeter.greet(T.unsafe(42)) }

        assert_match(/\AParameter 'name': Expected type String, got type Integer with value 42/, error.message)
        assert_empty logged_lines
      end

      def test_type_errors_are_logged_and_reported_in_production
        reported = []
        LogStruct.config.error_reporting_handler = ->(error, _context, source) { reported << [error.class, source] }

        result = LogStruct.stub(:is_production?, true) do
          Time.stub(:now, TIME) do
            # ----------------------------------------------------------
            # BEGIN CODE EXAMPLE: sorbet_type_error
            # ----------------------------------------------------------
            payload = JSON.parse('{"name": 42}')
            Greeter.greet(payload["name"])
            # ----------------------------------------------------------
            # END CODE EXAMPLE: sorbet_type_error
            # ----------------------------------------------------------
          end
        end

        # The code carries on with the wrong value
        assert_equal "Hello, 42", result
        assert_equal [[TypeError, Source::TypeChecking]], reported
        assert_equal page_json("TYPE_ERROR_LINE"), shortened(only_line)
        # The message goes on with the caller's and the method's file and line
        assert_match(/\nCaller: .*sorbet_types_test\.rb:\d+\nDefinition: .*sorbet_types_test\.rb:\d+ \(.*Greeter\.greet\)/, only_line["msg"])
        # The backtrace starts at the call, below sorbet-runtime's frames
        assert_match(/sorbet_types_test\.rb:\d+/, only_line["backtrace"]&.first)
      end

      def test_type_checking_mode
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: sorbet_type_checking_mode
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Log Sorbet type errors in every environment, without raising or reporting them
          config.error_handling_modes.type_checking_errors = LogStruct::ErrorHandlingMode::Log
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: sorbet_type_checking_mode
        # ----------------------------------------------------------
        reported = []
        LogStruct.config.error_reporting_handler = ->(error, _context, _source) { reported << error }

        refute_predicate LogStruct, :is_production?
        assert_equal "Hello, 42", Greeter.greet(T.unsafe(42))
        assert_equal "type_checking", only_line["src"]
        assert_empty reported
      end

      def test_struct_fields_are_type_checked
        # A field of the wrong type, and a missing required field (which srb tc reports, hence T.unsafe)
        assert_raises(TypeError) { Log::Request.new(http_method: "GET", path: "/users", status: T.unsafe("200")) }
        assert_raises(ArgumentError) { T.unsafe(Log::Error).new(source: Source::App, message: "Import failed") }

        # In production the type errors are logged and the structs are built
        LogStruct.config.error_reporting_handler = ->(_error, _context, _source) {}
        LogStruct.stub(:is_production?, true) do
          request = Log::Request.new(http_method: "GET", path: "/users", status: T.unsafe("200"))
          error_log = T.unsafe(Log::Error).new(source: Source::App, message: "Import failed")

          assert_equal "200", request.status
          assert_nil error_log.error_class
        end

        assert_equal ["type_checking", "type_checking"], logged_lines.map { |line| line["src"] }
      end

      def test_custom_log_line
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: custom_log_usage
          # ----------------------------------------------------------
          payment_log = TestApp::Log::Payments.new(
            event: TestApp::Log::Payments::Event::Processed,
            payment_id: "pay_123456",
            amount_cents: 9999,
            currency: "USD",
            status: "succeeded",
            user_id: 123,
            additional_data: {note: "Receipt sent to jo@example.com"}
          )
          LogStruct.info(payment_log)
          # ----------------------------------------------------------
          # END CODE EXAMPLE: custom_log_usage
          # ----------------------------------------------------------
        end

        assert_equal page_json("CUSTOM_LOG_LINE"), only_line
      end

      def test_additional_data_cannot_replace_the_common_fields
        payment_log = TestApp::Log::Payments.new(
          event: TestApp::Log::Payments::Event::Refunded,
          payment_id: "pay_1",
          amount_cents: 100,
          currency: "USD",
          status: "refunded",
          additional_data: {src: "billing"}
        )

        # A LogStruct error: raised in development and test
        error = assert_raises(ArgumentError) { payment_log.serialize }

        assert_equal "additional_data attempted to overwrite reserved key: src", error.message

        # Logged in production, and the key is left out
        serialized = LogStruct.stub(:is_production?, true) { payment_log.serialize }

        assert_equal "payments", serialized[:src]
        assert_equal [["logstruct", "additional_data attempted to overwrite reserved key: src"]],
          logged_lines.map { |line| [line["src"], line["msg"]] }
      end

      private

      def logged_lines
        ::SemanticLogger.flush
        @io.string.lines.map { |line| JSON.parse(line) }
      end

      def only_line
        lines = logged_lines

        assert_equal 1, lines.size, lines.inspect
        lines.first
      end

      # The page shows the message's first line, and no backtrace
      def shortened(line)
        line.except("backtrace").merge("msg" => line["msg"].lines.first.chomp)
      end

      def page_json(name) = docs_page_json(PAGE, name)
    end
  end
end
