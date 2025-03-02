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
      EmailDelivery = new(:delivery)
      EmailDelivered = new(:delivered)
      EmailError = new(:error)

      # Error event types
      Error = new(:error)
      Exception = new(:exception)
      Warning = new(:warning)

      # Third-party gem event types
      Shrine = new(:shrine)
      CarrierWave = new(:carrierwave)
      Sidekiq = new(:sidekiq)
    end
  end
end
