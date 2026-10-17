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

      SHRINE_EVENTS = T.let(%i[upload exists download delete metadata open].freeze, T::Array[Symbol])

      # Set up Shrine structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::Shrine)
        return nil unless config.enabled
        return nil unless config.integrations.enable_shrine

        # Create a structured log subscriber for Shrine
        # ActiveSupport::Notifications::Event has name, time, end, transaction_id, payload, and duration
        shrine_log_subscriber = lambda do |event|
          payload = event.payload.except(:io, :name).dup

          # Map event name to Event type
          event_type = case event.name
          when :upload then Event::Upload
          when :download then Event::Download
          when :open then Event::Download
          when :delete then Event::Delete
          when :exists then Event::Exist
          else Event::Metadata
          end

          # Create structured log data
          # Ensure storage is always a symbol
          storage_sym = payload[:storage].to_sym

          log_data = case event_type
          when Event::Upload
            metadata = payload[:metadata].is_a?(Hash) ? payload[:metadata] : {}
            size = metadata["size"]
            Log::Shrine::Upload.new(
              storage: storage_sym,
              location: payload[:location],
              filename: metadata["filename"]&.to_s,
              mime_type: metadata["mime_type"]&.to_s,
              size: size.is_a?(Integer) ? size : nil,
              uploader: payload[:uploader]&.to_s,
              upload_options: payload[:upload_options],
              options: payload[:options],
              duration_ms: event.duration.to_f
            )
          when Event::Download
            Log::Shrine::Download.new(
              storage: storage_sym,
              location: payload[:location],
              download_options: payload[:download_options]
            )
          when Event::Delete
            Log::Shrine::Delete.new(
              storage: storage_sym,
              location: payload[:location]
            )
          when Event::Exist
            Log::Shrine::Exist.new(
              storage: storage_sym,
              location: payload[:location]
            )
          else
            # metadata, the only other event in SHRINE_EVENTS
            Log::Shrine::Metadata.new(storage: storage_sym, duration_ms: event.duration.to_f)
          end

          # Log directly through SemanticLogger, NOT through Shrine.logger
          # Shrine.logger is a basic Logger that would just call .to_s on the struct
          ::SemanticLogger[::Shrine].info(log_data)
        end

        # Load the instrumentation plugin without Shrine's default log subscriber, which logs
        # each event as a line of text (a no-op if the app has loaded it already). Shrine
        # ignores a subscriber that's already subscribed.
        ::Shrine.plugin :instrumentation, log_subscriber: nil
        SHRINE_EVENTS.each do |event_name|
          ::Shrine.subscribe(event_name, &shrine_log_subscriber)
        end

        # The app may load the plugin with the default log subscriber too, before or after this
        ::Shrine::Plugins::Instrumentation::LogSubscriber.singleton_class.prepend(SkipLoggedEvents)

        # Other plugins' log subscribers and Shrine's warnings write text to Shrine.logger
        ::Shrine.logger = ::SemanticLogger[::Shrine]

        true
      end

      # Prepended to Shrine's default instrumentation log subscriber, so it doesn't log the
      # events that LogStruct logs
      module SkipLoggedEvents
        extend T::Sig

        sig { params(event: T.untyped).returns(T.untyped) }
        def call(event)
          return if SHRINE_EVENTS.include?(event.name)

          super
        end
      end
    end
  end
end
