# typed: strict
# frozen_string_literal: true

begin
  require "shrine"
rescue LoadError
  # Shrine gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # Shrine integration for structured logging
    module Shrine
      extend T::Sig
      extend IntegrationInterface

      # Set up Shrine structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::Shrine)
        return nil unless config.enabled
        return nil unless config.integrations.enable_shrine

        # Create a structured log subscriber for Shrine
        # ActiveSupport::Notifications::Event has name, time, end, transaction_id, payload, and duration
        shrine_log_subscriber = T.unsafe(lambda do |event|
          payload = event.payload.except(:io, :metadata, :name).dup

          # Map event name to Event type
          event_type = case event.name
          when :upload then Event::Upload
          when :download then Event::Download
          when :delete then Event::Delete
          when :metadata then Event::Metadata
          when :exists then Event::Exist # ActiveStorage uses 'exist', may as well use that
          else Event::Unknown
          end

          # Create structured log data
          # Ensure storage is always a symbol
          storage_sym = payload[:storage].to_sym

          log_data = case event_type
          when Event::Upload
            Log::Shrine::Upload.new(
              storage: storage_sym,
              location: payload[:location],
              uploader: payload[:uploader],
              upload_options: payload[:upload_options],
              options: payload[:options],
              duration_ms: event.duration,
              additional_data: payload.except(:storage, :location, :uploader, :upload_options, :options)
            )
          when Event::Download
            Log::Shrine::Download.new(
              storage: storage_sym,
              location: payload[:location],
              download_options: payload[:download_options],
              additional_data: payload.except(:storage, :location, :download_options)
            )
          when Event::Delete
            Log::Shrine::Delete.new(
              storage: storage_sym,
              location: payload[:location],
              additional_data: payload.except(:storage, :location)
            )
          when Event::Metadata
            Log::Shrine::Metadata.new(
              storage: storage_sym,
              location: payload[:location],
              metadata: payload[:metadata],
              additional_data: payload.except(:storage, :location, :metadata)
            )
          when Event::Exist
            Log::Shrine::Exist.new(
              storage: storage_sym,
              location: payload[:location],
              exist: payload[:exist],
              additional_data: payload.except(:storage, :location, :exist)
            )
          else
            Log::Shrine::Metadata.new(
              storage: storage_sym,
              location: payload[:location],
              metadata: payload[:metadata]
            )
          end

          # Pass the structured hash to the logger
          # If Rails.logger has our Formatter, it will handle JSON conversion
          ::Shrine.logger.info log_data
        end)

        # Configure Shrine to use our structured log subscriber
        ::Shrine.plugin :instrumentation,
          events: %i[upload exists download delete],
          log_subscriber: shrine_log_subscriber

        true
      end
    end
  end
end
