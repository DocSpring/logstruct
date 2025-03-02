# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log event types as an enum
  class LogEvent < T::Enum
    enums do
      # Plain log message (e.g. calling Rails.logger.info with a string)
      Log = new(:log)

      # Rails and Rails-related event types
      Request = new(:request)
      SecurityViolation = new(:security_violation)
      RequestError = new(:request_error)
      JobExecution = new(:job_execution)
      Storage = new(:storage)
      FileOperation = new(:file_operation)
      Notification = new(:notification)

      # Email Event Types
      Delivery = new(:delivery)
      Delivered = new(:delivered)

      # Error event types
      Error = new(:error)
    end
  end
end
