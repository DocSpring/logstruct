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

        detach_rails_log_subscriber

        # Subscribe to all ActiveStorage service events
        ::ActiveSupport::Notifications.subscribe(/service_.*\.active_storage/) do |*args|
          process_active_storage_event(::ActiveSupport::Notifications::Event.new(*args), config)
        rescue => e
          # A problem with a line mustn't fail the upload or download it describes
          LogStruct.handle_exception(e, source: Source::Internal, context: {integration: :active_storage})
        end

        true
      end

      # LogStruct's lines replace Rails' own ActiveStorage lines. Rails loads its log subscriber with
      # the storage service, after LogStruct is set up, so it's loaded here to detach it.
      sig { void }
      def self.detach_rails_log_subscriber
        require "active_storage/log_subscriber"
        RailsLogSubscribers.detach(::ActiveStorage::LogSubscriber, :active_storage)
      rescue LoadError
        nil
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
        when "service_download_chunk", "service_streaming_download"
          Event::Download
        when "service_update_metadata"
          Event::Metadata
        else
          # Events with no line of their own, such as service_mirror
          return
        end

        # Create structured log event using generated classes
        log_data = case event_type
        when Event::Upload
          Log::ActiveStorage::Upload.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s,
            checksum: event.payload[:checksum]&.to_s,
            duration_ms: duration_ms
          )
        when Event::Download
          Log::ActiveStorage::Download.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s,
            range: event.payload[:range],
            duration_ms: duration_ms
          )
        when Event::Delete
          # delete_prefixed has a prefix instead of a key
          Log::ActiveStorage::Delete.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s,
            prefix: event.payload[:prefix]&.to_s
          )
        when Event::Metadata
          Log::ActiveStorage::Metadata.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s,
            mime_type: event.payload[:content_type]&.to_s
          )
        when Event::Exist
          Log::ActiveStorage::Exist.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s,
            exist: event.payload[:exist]
          )
        when Event::Url
          # Without the URL: it's signed, and anyone who has it can read the file until it expires
          Log::ActiveStorage::Url.new(
            storage: service_name.to_sym,
            file_id: event.payload[:key]&.to_s
          )
        end

        # Rails logs existence checks and URLs at debug level: an app generates a URL for each file it shows
        if event_type == Event::Exist || event_type == Event::Url
          LogStruct.debug(log_data)
        else
          LogStruct.info(log_data)
        end
      end
    end
  end
end
