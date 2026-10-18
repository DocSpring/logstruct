# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class ConfigureHandlersTest < ActiveSupport::TestCase
      def test_lograge_custom_options
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: lograge_custom_options
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Add fields to every request line: return a Hash of fields, or change options in place.
          # Fields that are nil are left out.
          config.integrations.lograge_custom_options = ->(event, _options) {
            {user_id: event.payload[:user_id], account_id: event.payload[:account_id]}
          }
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: lograge_custom_options
        # ----------------------------------------------------------

        event = ActiveSupport::Notifications::Event.new(
          "process_action.action_controller", Time.now.to_f, Time.now.to_f, "event-id", {user_id: 123, headers: {}}
        )
        options = LogStruct::Integrations::Lograge.lograge_default_options(event)
        line = LogStruct::Integrations::Lograge.build_request_log(options.merge(method: "GET", path: "/")).serialize

        assert_equal 123, line[:user_id]
        refute line.key?(:account_id)
      end

      def test_custom_string_scrubber
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: custom_string_scrubber
        # ----------------------------------------------------------
        # Called with every string LogStruct writes, after its own scrubbers. Return the scrubbed string.
        LogStruct.configure do |config|
          config.string_scrubbing_handler = ->(value) {
            # Replace numbers that look like bank account numbers
            value.gsub(/\b\d{10,12}\b/, "[BANK_ACCOUNT]")
          }
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: custom_string_scrubber
        # ----------------------------------------------------------

        # Test that the string scrubber is properly set
        assert_kind_of Proc, LogStruct.configuration.string_scrubbing_handler

        # Test with a string containing a bank account number
        test_string = "Customer with bank account 1234567890 needs help"
        handler = T.must(LogStruct.configuration.string_scrubbing_handler)
        result = handler.call(test_string)

        # Verify it replaced the account number
        assert_equal "Customer with bank account [BANK_ACCOUNT] needs help", result

        # Test with a string that doesn't match the pattern
        test_string = "Customer with account 12345 needs help"
        handler = T.must(LogStruct.configuration.string_scrubbing_handler)
        result = handler.call(test_string)

        # Verify it didn't change anything
        assert_equal "Customer with account 12345 needs help", result
      end

      class ErrorTracker
        class << self
          def notifications = (@notifications ||= [])

          def notify(error, context:, source:) = notifications << [error, context, source]
        end
      end

      def test_error_reporting_handler
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: error_reporting_handler
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Called for each error LogStruct reports, in place of Sentry, Bugsnag, Rollbar or Honeybadger.
          # The context is filtered and scrubbed like a log line.
          config.error_reporting_handler = ->(error, context, source) {
            ErrorTracker.notify(error, context: context, source: source.serialize)
          }
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: error_reporting_handler
        # ----------------------------------------------------------

        error = RuntimeError.new("Test error message")
        LogStruct.report_error(error, source: LogStruct::Source::App, context: {user_id: 123, password: "hunter2"})

        reported_error, context, source = ErrorTracker.notifications.last

        assert_same error, reported_error
        assert_equal 123, context[:user_id]
        assert_equal({_filtered: {_class: String}}, context[:password])
        assert_equal :app, source
      ensure
        ErrorTracker.notifications.clear
      end

      def test_choose_error_reporter
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: choose_error_reporter
        # ----------------------------------------------------------
        # LogStruct reports to the first of Sentry, Bugsnag, Rollbar and Honeybadger that's loaded
        # (with none, it logs the error). To choose one when your app loads several:
        LogStruct::MultiErrorReporter.reporter = :bugsnag
        # ----------------------------------------------------------
        # END CODE EXAMPLE: choose_error_reporter
        # ----------------------------------------------------------

        assert_equal LogStruct::ErrorReporter::Bugsnag, LogStruct::MultiErrorReporter.reporter
      ensure
        # Detect the reporter again
        LogStruct::MultiErrorReporter.instance_variable_set(:@reporter_impl, nil)
      end
    end
  end
end
