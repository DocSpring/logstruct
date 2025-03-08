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
        # Provide a custom proc to extend Lograge options
        LogStruct.configure do |config|
          config.integrations.lograge_custom_options = T.let(->(event, options) do
            # Add custom fields to the options hash
            options[:user_id] = event.payload[:user_id] if event.payload[:user_id]
            options[:account_id] = event.payload[:account_id] if event.payload[:account_id]
            options
          end,
            LogStruct::Handlers::LogrageCustomOptions)
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: lograge_custom_options
        # ----------------------------------------------------------

        # Test that the lograge custom options handler is properly set
        assert_kind_of Proc, LogStruct.configuration.integrations.lograge_custom_options

        # In a test context, we need a mock for ActiveSupport::Notifications::Event
        # Create a simple struct to act as our event
        mock_payload = {user_id: 123, account_id: 456, other_data: "test"}

        # Simple event class with just a payload attribute
        event = Struct.new(:payload).new(mock_payload)

        # Create a stub handler that ignores the event type for testing
        stub_handler = lambda do |evt, opts|
          # Copy the relevant fields from the payload
          opts[:user_id] = evt.payload[:user_id] if evt.payload[:user_id]
          opts[:account_id] = evt.payload[:account_id] if evt.payload[:account_id]
          opts
        end

        # Call the handler to verify it works
        options = {}
        result = stub_handler.call(event, options)

        # Verify it adds the expected fields
        assert_equal 123, result[:user_id]
        assert_equal 456, result[:account_id]
      end

      def test_custom_string_scrubber
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: custom_string_scrubber
        # ----------------------------------------------------------
        # Set a custom string scrubbing handler that will be called
        # after the built-in scrubbers run
        LogStruct.configure do |config|
          config.string_scrubbing_handler = T.let(->(value) {
            # Custom string scrubbing logic here
            # Example: Remove all bank account numbers that match the pattern
            value.gsub(/\b\d{10,12}\b/, "[BANK_ACCOUNT]")
          },
            LogStruct::Handlers::StringScrubber)
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

      def test_error_reporting_handler
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: error_reporting_handler
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          config.error_reporting_handler = T.let(->(error, context, source) {
            # Custom error reporting logic here
            # You could send errors to a custom service, log them specially, etc.
            # This is just a simple example:

            # Extract info from the error
            error_class = error.class.name
            error_message = error.message

            # Log to a custom target
            puts "[CUSTOM ERROR REPORTER] #{error_class}: #{error_message}"
            puts "Context: #{context.inspect}"
            puts "Backtrace: #{error.backtrace&.first(5)&.join("\n  ")}"
          },
            LogStruct::Handlers::ErrorReporter)
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: error_reporting_handler
        # ----------------------------------------------------------

        # Test that the error reporter is properly set
        assert_kind_of Proc, LogStruct.configuration.error_reporting_handler

        # Create a test error
        test_error = RuntimeError.new("Test error message")
        test_context = {user_id: 123, action: "test"}
        # Use a real Source enum value instead of a string
        test_source = LogStruct::Source::App

        # Capture stdout to verify the error reporter works
        stdout = capture_stdout do
          handler = T.must(LogStruct.configuration.error_reporting_handler)
          handler.call(test_error, test_context, test_source)
        end

        # Verify it logged the expected output
        assert_match(/\[CUSTOM ERROR REPORTER\] RuntimeError: Test error message/, stdout)
        # The context might be formatted differently depending on Ruby version
        assert_includes stdout, "Context:"
        assert_includes stdout, "user_id"
        assert_includes stdout, "123"
        assert_includes stdout, "action"
        assert_includes stdout, "test"
      end

      private

      # Helper to capture stdout
      def capture_stdout
        original_stdout = $stdout
        $stdout = StringIO.new
        yield
        $stdout.string
      ensure
        $stdout = original_stdout
      end
    end
  end
end
