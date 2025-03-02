# typed: true
# frozen_string_literal: true

begin
  require "active_storage"
rescue LoadError
  # ActiveStorage may not be available, integration will be skipped
end

module LogStruct
  module Integrations
    # ActiveStorage integration for structured logging
    module ActiveStorage
      class << self
        # Set up ActiveStorage structured logging
        sig { void }
        def setup
          return unless defined?(::ActiveStorage)
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.active_storage_integration_enabled

          # Subscribe to ActiveStorage service events
          ActiveSupport::Notifications.subscribe(/service/) do |event|
            process_active_storage_event(event)
          end
        end

        private

        # Process ActiveStorage service events and log them
        sig { params(event: ActiveSupport::Notifications::Event).void }
        def process_active_storage_event(event)
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.active_storage_integration_enabled

          # Extract event data
          event_name = event.name.to_s
          operation = event_name.split(".").last
          payload = event.payload.dup
          service = payload[:service] || "unknown"

          # Create structured log data
          log_data = Log::Storage.new(
            src: LogSource::Storage,
            evt: LogEvent::Storage,
            operation: operation,
            service: service,
            key: payload[:key],
            checksum: payload[:checksum],
            byte_size: payload[:byte_size],
            content_type: payload[:content_type],
            metadata: payload[:metadata],
            duration: event.duration
          )

          # Log the structured data
          Rails.logger.info(log_data)
        end
      end
    end
  end
end
