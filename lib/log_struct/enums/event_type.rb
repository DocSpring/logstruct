# typed: strict
# frozen_string_literal: true

module LogStruct
  module Enums
    # Define event types as an enum
    class EventType < T::Enum
      enums do
        # General event types
        Request = new(:request)
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
