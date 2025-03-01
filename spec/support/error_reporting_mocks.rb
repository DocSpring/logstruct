# frozen_string_literal: true
# typed: false

# This file contains mock implementations of error reporting services
# for use in tests. These mocks are designed to be compatible with
# the RailsStructuredLogging::MultiErrorReporter class.

# Mock Sentry module
module Sentry
  # Capture an exception with optional context
  # @param exception [Exception] The exception to capture
  # @param options [Hash] Additional options for the capture
  def self.capture_exception(exception, options = {})
    # Mock implementation
  end
end

# Mock Bugsnag module
module Bugsnag
  # Notify Bugsnag of an exception
  # @param exception [Exception] The exception to notify
  # @yield [report] The report to add metadata to
  def self.notify(exception)
    yield OpenStruct.new(
      add_metadata: ->(section, data) { }
    ) if block_given?
  end
end

# Mock Rollbar module
module Rollbar
  # Report an error to Rollbar
  # @param exception [Exception] The exception to report
  # @param context [Hash] Additional context for the error
  def self.error(exception, context = {})
    # Mock implementation
  end
end

# Mock Honeybadger module
module Honeybadger
  # Notify Honeybadger of an exception
  # @param exception [Exception] The exception to notify
  # @param options [Hash] Additional options for the notification
  def self.notify(exception, options = {})
    # Mock implementation
  end
end

# Mock Postmark error classes
module Postmark
  class Error < StandardError; end

  class InactiveRecipientError < Error
    attr_reader :recipients

    def initialize(message, recipients = [])
      super(message)
      @recipients = recipients
    end
  end

  class InvalidEmailRequestError < Error; end
end

# Mock ApplicationMailer
class ApplicationMailer
  class AbortDeliveryError < StandardError; end
end
