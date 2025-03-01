# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module RailsStructuredLogging
  module Enums
    # Define event types as an enum
    class EventType < T::Enum
      extend T::Sig

      enums do
        # General event types
        SecurityViolation = new(:security_violation)
        RequestError = new(:request_error)
        JobExecution = new(:job_execution)
        FileOperation = new(:file_operation)
        Notification = new(:notification)

        # Email event types
        EmailDelivery = new(:email_delivery)
        EmailDelivered = new(:email_delivered)
        EmailError = new(:email_error)
      end
    end
  end
end
