# typed: strict
# frozen_string_literal: true

require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../log/storage"

module LogStruct
  module Integrations
    # Integration for ActiveStorage structured logging
    module ActiveStorage
      extend IntegrationInterface

      class << self
        extend T::Sig

        # Set up ActiveStorage structured logging
        sig { override.params(config: LogStruct::Configuration).void }
        def setup(config)
          return unless defined?(::ActiveStorage)
          return unless config.enabled
          return unless config.integrations.enable_active_storage

          # Subscribe to all ActiveStorage service events
          ::ActiveSupport::Notifications.subscribe(/service_.*\.active_storage/) do |*args|
            process_active_storage_event(::ActiveSupport::Notifications::Event.new(*args), config)
          end
        end

        private

        # Process ActiveStorage events and create structured logs
        sig { params(event: ActiveSupport::Notifications::Event, config: LogStruct::Configuration).void }
        def process_active_storage_event(event, config)
          return unless config.enabled
          return unless config.integrations.enable_active_storage

          # Extract key information from the event
          event_name = event.name.sub(/\.active_storage$/, "")
          service_name = event.payload[:service]
          duration = event.duration

          # Map service events to log event types
          event_type = case event_name.to_sym
          when :service_upload
            LogEvent::Upload
          when :service_download, :service_download_chunk
            LogEvent::Download
          when :service_delete, :service_delete_prefixed
            LogEvent::Delete
          when :service_exist
            LogEvent::Exist
          when :service_url
            LogEvent::Url
          when :service_stream
            LogEvent::Stream
          when :service_update_metadata
            LogEvent::Metadata
          else
            LogEvent::Unknown
          end

          # Create structured log event for this storage operation
          log_data = Log::ActiveStorage.new(
            event: event_type,
            checksum: event.payload[:checksum].to_s,
            duration: duration
          )

          # Log structured data
          LogStruct.log(log_data)
        end
      end
    end
  end
end
