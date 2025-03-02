# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log event types as an enum
  class LogEvent < T::Enum
    enums do
      # Plain log message (e.g. calling Rails.logger.info with a string)
      Log = new(:log)

      # Request logs (from Lograge)
      Request = new(:request)
      # Request error logs (from Rack::ErrorHandlingMiddleware)
      RequestError = new(:request_error)
      # Security logs (from HostAuthorization - IP spoof, CSRF, blocked hosts, etc.)
      Security = new(:security)
      # Job execution logs (from ActiveJob)
      JobExecution = new(:job_execution)
      # Notification logs (from ActiveSupport::Notifications)
      Notification = new(:notification)

      # File storage event types (Shrine, CarrierWave, ActiveStorage)
      Upload = new(:upload)
      Download = new(:download)
      Delete = new(:delete)
      Metadata = new(:metadata)
      Exist = new(:exist) # ActiveStorage: exist, Shrine: exists

      # Email Event Types
      Delivery = new(:delivery)
      Delivered = new(:delivered)

      # Error event types
      Error = new(:error)

      # Fallback for unknown event types
      Unknown = new(:unknown)
    end
  end
end
