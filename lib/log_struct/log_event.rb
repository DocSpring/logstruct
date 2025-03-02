# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log event types as an enum
  class LogEvent < T::Enum
    enums do
      # Plain log message (e.g. calling Rails.logger.info with a string)
      Log = new(:log)

      # LogStruct Event Types
      Request = new(:request)
      SecurityViolation = new(:security_violation)
      RequestError = new(:request_error)
      JobExecution = new(:job_execution)
      FileOperation = new(:file_operation)
      Notification = new(:notification)

      # Email Event Types
      EmailDelivery = new(:delivery)
      EmailDelivered = new(:delivered)
      EmailError = new(:error)

      # Error event types
      Error = new(:error)
      Exception = new(:exception)
      Warning = new(:warning)
    end
  end
end
