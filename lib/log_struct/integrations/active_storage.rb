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
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::ActiveStorage)
        return nil unless config.enabled
        return nil unless config.integrations.enable_activestorage

        # Subscribe to all ActiveStorage service events
        ::ActiveSupport::Notifications.subscribe(/service_.*\.active_storage/) do |*args|
          process_active_storage_event(::ActiveSupport::Notifications::Event.new(*args), config)
        end

        true
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
        duration_ms = event.duration

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
        event_name.sub(/^service_/, "").to_sym

        # Create structured log event using generated classes
        log_data = case event_type
        when Event::Upload
          Log::ActiveStorage::Upload.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            checksum: event.payload[:checksum]&.to_s,
            duration_ms: duration_ms,
            metadata: event.payload[:metadata],
            filename: event.payload[:filename],
            mime_type: event.payload[:content_type],
            size: event.payload[:byte_size]
          )
        when Event::Download
          Log::ActiveStorage::Download.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            filename: event.payload[:filename],
            range: event.payload[:range],
            duration_ms: duration_ms
          )
        when Event::Delete
          Log::ActiveStorage::Delete.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s
          )
        when Event::Metadata
          Log::ActiveStorage::Metadata.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            metadata: event.payload[:metadata]
          )
        when Event::Exist
          Log::ActiveStorage::Exist.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            exist: event.payload[:exist]
          )
        when Event::Stream
          Log::ActiveStorage::Stream.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            prefix: event.payload[:prefix]
          )
        when Event::Url
          Log::ActiveStorage::Url.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            url: event.payload[:url]
          )
        else
          Log::ActiveStorage::Metadata.new(
            storage: service_name.to_s,
            file_id: event.payload[:key]&.to_s,
            metadata: event.payload[:metadata]
          )
        end

        # Log structured data
        LogStruct.info(log_data)
      end
    end
  end
end
