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
          log_data = Log::Shrine.new(
            source: Source::Shrine,
            event: event_type,
            duration: event.duration,
            storage: payload[:storage],
            location: payload[:location],
            uploader: payload[:uploader],
            upload_options: payload[:upload_options],
            download_options: payload[:download_options],
            options: payload[:options],
            # Data is flattened by the JSON formatter
            additional_data: payload.except(
              :storage,
              :location,
              :uploader,
              :upload_options,
              :download_options,
              :options
            )
          )

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
