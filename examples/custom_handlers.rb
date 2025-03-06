# typed: strict
# frozen_string_literal: true

require "log_struct"

# Example of configuring LogStruct with custom handlers
# Shows how to implement and configure custom string scrubbing and error reporting
module Examples
  extend T::Sig

  # ----------------------------------------------------------
  # BEGIN CODE EXAMPLE: custom_string_scrubber
  # ----------------------------------------------------------
  # Set a custom string scrubbing handler that will be called
  # after the built-in scrubbers run
  LogStruct.configuration.string_scrubbing_handler = T.let(->(value) {
    # Custom string scrubbing logic here
    # Example: Remove all bank account numbers that match the pattern
    value.gsub(/\b\d{10,12}\b/, "[BANK_ACCOUNT]")
  },
    LogStruct::Handlers::StringScrubber)
  # ----------------------------------------------------------
  # END CODE EXAMPLE: custom_string_scrubber
  # ----------------------------------------------------------

  # ----------------------------------------------------------
  # BEGIN CODE EXAMPLE: custom_error_reporter
  # ----------------------------------------------------------
  # Set a custom error reporting handler to send errors to your own system
  # This will be used instead of the default MultiErrorReporter
  LogStruct.configuration.error_reporting_handler = T.let(->(error, context, source) {
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
  # END CODE EXAMPLE: custom_error_reporter
  # ----------------------------------------------------------
end
