# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module RailsStructuredLogging
  module LogTypes
    # Define event types as an enum
    class EventType < T::Enum
      extend T::Sig

      enums do
        SecurityViolation = new(:security_violation)
        RequestError = new(:request_error)
        EmailDelivery = new(:email_delivery)
        JobExecution = new(:job_execution)
        FileOperation = new(:file_operation)
        Notification = new(:notification)
      end
    end
  end
end
