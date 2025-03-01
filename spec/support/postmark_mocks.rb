# frozen_string_literal: true

# Mock Postmark error classes for testing
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
