# typed: strict
# frozen_string_literal: true

require "log_struct"

# Example of configuring LogStruct with custom handlers
# Shows how to implement and configure custom string scrubbing and error reporting
module Examples
  extend T::Sig

  sig { void }
  def self.handler_examples
    LogStruct.configure do |config|
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: lograge_custom_options
      # ----------------------------------------------------------
      # Provide a custom proc to extend Lograge options
      config.integrations.lograge_custom_options = T.let(->(event, options) do
        # Add custom fields to the options hash
        options[:user_id] = event.payload[:user_id] if event.payload[:user_id]
        options[:account_id] = event.payload[:account_id] if event.payload[:account_id]
        options
      end,
        LogStruct::Handlers::LogrageCustomOptions)
      # ----------------------------------------------------------
      # END CODE EXAMPLE: lograge_custom_options
      # ----------------------------------------------------------

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: custom_string_scrubber
      # ----------------------------------------------------------
      # Set a custom string scrubbing handler that will be called
      # after the built-in scrubbers run
      config.string_scrubbing_handler = T.let(->(value) {
        # Custom string scrubbing logic here
        # Example: Remove all bank account numbers that match the pattern
        value.gsub(/\b\d{10,12}\b/, "[BANK_ACCOUNT]")
      },
        LogStruct::Handlers::StringScrubber)
      # ----------------------------------------------------------
      # END CODE EXAMPLE: custom_string_scrubber
      # ----------------------------------------------------------

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: error_reporting_handler
      # ----------------------------------------------------------
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
      # ----------------------------------------------------------
      # END CODE EXAMPLE: error_reporting_handler
      # ----------------------------------------------------------
    end
  end
end
