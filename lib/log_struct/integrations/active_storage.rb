# typed: strict
# frozen_string_literal: true

require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../log/active_storage"

module LogStruct
  module Integrations
    # Integration for ActiveStorage structured logging
    module ActiveStorage
      extend T::Sig
      extend IntegrationInterface

      # Set up ActiveStorage structured logging
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless defined?(::ActiveStorage)
        return unless config.enabled
        return unless config.integrations.enable_activestorage

        # Subscribe to all ActiveStorage service events
        ::ActiveSupport::Notifications.subscribe(/service_.*\.active_storage/) do |*args|
          process_active_storage_event(::ActiveSupport::Notifications::Event.new(*args), config)
        end
      end

      private_class_method

      # Process ActiveStorage events and create structured logs
      sig { params(event: ActiveSupport::Notifications::Event, config: LogStruct::Configuration).void }
      def self.process_active_storage_event(event, config)
        return unless config.enabled
        return unless config.integrations.enable_activestorage

        # Extract key information from the event
        event_name = event.name.sub(/\.active_storage$/, "")
        service_name = event.payload[:service]
        duration = event.duration

        # Map service events to log event types
        event_type = case event_name
        when "service_upload"
          Event::Upload
        when "service_download"
          Event::Download
        when "service_delete"
          Event::Delete
        when "service_delete_prefixed"
          Event::Delete
        when "service_exist"
          Event::Exist
        when "service_url"
          Event::Url
        when "service_download_chunk"
          Event::Download
        when "service_stream"
          Event::Stream
        when "service_update_metadata"
          Event::Metadata
        else
          Event::Unknown
        end

        # Map the event name to an operation
        operation = event_name.sub(/^service_/, "").to_sym

        # Create structured log event specific to ActiveStorage
        log_data = Log::ActiveStorage.new(
          event: event_type,
          operation: operation,
          storage: service_name.to_s,
          file_id: event.payload[:key].to_s,
          checksum: event.payload[:checksum].to_s,
          duration: duration,
          # Add other fields where available
          metadata: event.payload[:metadata],
          exist: event.payload[:exist],
          url: event.payload[:url],
          filename: event.payload[:filename],
          mime_type: event.payload[:content_type],
          size: event.payload[:byte_size],
          prefix: event.payload[:prefix],
          range: event.payload[:range]
        )

        # Log structured data
        LogStruct.log(log_data)
      end
    end
  end
end
