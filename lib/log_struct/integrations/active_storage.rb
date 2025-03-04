# typed: true
# frozen_string_literal: true

require_relative "../log_source"
require_relative "../log_event"
require_relative "../log/storage"

module LogStruct
  module Integrations
    # Integration for ActiveStorage structured logging
    module ActiveStorage
      class << self
        # Set up ActiveStorage structured logging
        def setup
          return unless defined?(::ActiveStorage)

          # Subscribe to all ActiveStorage service events
          ::ActiveSupport::Notifications.subscribe(/service_.*\.active_storage/) do |*args|
            process_active_storage_event(::ActiveSupport::Notifications::Event.new(*args))
          end
        end

        private

        # Process ActiveStorage events and create structured logs
        def process_active_storage_event(event)
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_active_storage

          payload = event.payload
          # Extract operation from event name (e.g., "service_upload.active_storage" -> "upload")
          operation = event.name.split(".").first.sub("service_", "")
          service = payload[:service] || "unknown"

          # Map operation to appropriate event type
          event_type = case operation
          when "upload" then LogEvent::Upload
          when "download", "streaming_download", "download_chunk" then LogEvent::Download
          when "delete", "delete_prefixed" then LogEvent::Delete
          when "exist" then LogEvent::Exist
          else LogEvent::Unknown
          end

          # Create structured log data
          log_data = Log::Storage.new(
            source: Source::Storage,
            event: event_type,
            operation: operation,
            storage: service,
            file_id: payload[:key],
            mime_type: payload[:content_type],
            size: payload[:byte_size],
            metadata: payload[:metadata],
            duration: event.duration,
            # Store additional fields in the data hash (flattened by JSON formatter)

            checksum: payload[:checksum],
            exist: payload[:exist],
            url: payload[:url],
            prefix: payload[:prefix],
            range: payload[:range]
          )

          # Log the structured data
          Rails.logger.info(log_data)
        end
      end
    end
  end
end
