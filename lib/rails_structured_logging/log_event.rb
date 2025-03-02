# typed: strict
# frozen_string_literal: true

module RailsStructuredLogging
  # Define log event types as an enum
  class LogEvent < T::Enum
    enums do
      # General event types
      Log = new(:log)
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

      # Error event types
      Error = new(:error)
      Exception = new(:exception)
      Warning = new(:warning)
    end
  end
end
