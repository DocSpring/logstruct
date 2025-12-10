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
        LogStruct::Debug.log(:shrine, "setup called")

        unless defined?(::Shrine)
          LogStruct::Debug.log(:shrine, "  RETURNING NIL: ::Shrine not defined")
          return nil
        end
        unless config.enabled
          LogStruct::Debug.log(:shrine, "  RETURNING NIL: config not enabled")
          return nil
        end
        unless config.integrations.enable_shrine
          LogStruct::Debug.log(:shrine, "  RETURNING NIL: shrine integration not enabled")
          return nil
        end

        LogStruct::Debug.log(:shrine, "  All checks passed, setting up subscriber")

        # Create a structured log subscriber for Shrine
        # ActiveSupport::Notifications::Event has name, time, end, transaction_id, payload, and duration
        shrine_log_subscriber = T.unsafe(lambda do |event|
          LogStruct::Debug.log(:shrine, "subscriber called, event=#{event.name}")

          payload = event.payload.except(:io, :metadata, :name).dup

          # Map event name to Event type
          # Shrine uses "event.shrine" format for AS::Notifications (e.g., "upload.shrine")
          # Handle both symbol form (internal) and string form (AS::Notifications)
          event_name = event.name.to_s.sub(/\.shrine$/, "").to_sym
          event_type = case event_name
          when :upload then Event::Upload
          when :download then Event::Download
          when :open then Event::Download
          when :delete then Event::Delete
          when :metadata then Event::Metadata
          when :exists then Event::Exist
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
          when Event::Metadata
            metadata_params = {
              storage: storage_sym,
              metadata: payload[:metadata]
            }
            metadata_params[:location] = payload[:location] if payload[:location]
            Log::Shrine::Metadata.new(**metadata_params)
          when Event::Exist
            Log::Shrine::Exist.new(
              storage: storage_sym,
              location: payload[:location],
              exist: payload[:exist]
            )
          else
            unknown_params = {storage: storage_sym, metadata: payload[:metadata]}
            unknown_params[:location] = payload[:location] if payload[:location]
            Log::Shrine::Metadata.new(**unknown_params)
          end

          # Log directly through SemanticLogger, NOT through Shrine.logger
          # Shrine.logger is a basic Logger that would just call .to_s on the struct
          ::SemanticLogger[::Shrine].info(log_data)
        end)

        # Check if instrumentation plugin is already loaded
        # If so, we need to replace the existing subscribers, not add duplicates
        already_configured = instrumentation_already_configured?
        LogStruct::Debug.log(:shrine, "  instrumentation_already_configured? = #{already_configured}")

        if already_configured
          LogStruct::Debug.log(:shrine, "  PATH: Replacing existing subscribers")
          replace_existing_subscribers(shrine_log_subscriber)
        else
          LogStruct::Debug.log(:shrine, "  PATH: First time setup - calling Shrine.plugin :instrumentation")
          # First time setup - configure the instrumentation plugin
          ::Shrine.plugin :instrumentation,
            events: SHRINE_EVENTS,
            log_subscriber: shrine_log_subscriber
        end

        LogStruct::Debug.log(:shrine, "  Setup complete")
        true
      end

      sig { returns(T::Boolean) }
      def self.instrumentation_already_configured?
        return false unless defined?(::Shrine)

        opts = T.unsafe(::Shrine).opts
        return false unless opts.is_a?(Hash)

        instrumentation_opts = opts[:instrumentation]
        return false unless instrumentation_opts.is_a?(Hash)

        subscribers = instrumentation_opts[:subscribers]
        return false unless subscribers.is_a?(Hash)

        !subscribers.empty?
      end

      sig { params(new_subscriber: T.untyped).void }
      def self.replace_existing_subscribers(new_subscriber)
        LogStruct::Debug.log(:shrine, "replace_existing_subscribers called")

        opts = T.unsafe(::Shrine).opts
        instrumentation_opts = opts[:instrumentation]

        # CRITICAL: Replace the log_subscriber option itself.
        # This is what produces the "Upload (Xms) – {storage: ...}" format.
        # If we don't replace this, Shrine's default subscriber still runs.
        instrumentation_opts[:log_subscriber] = new_subscriber
        LogStruct::Debug.log(:shrine, "  Replaced :log_subscriber with our subscriber")

        # Ensure subscribers hash exists
        instrumentation_opts[:subscribers] ||= {}
        subscribers = T.cast(instrumentation_opts[:subscribers], T::Hash[Symbol, T::Array[T.untyped]])

        # Clear all existing subscribers and add our new one
        SHRINE_EVENTS.each do |event_name|
          subscribers[event_name] = [new_subscriber]

          # Also re-subscribe via ActiveSupport::Notifications
          # IMPORTANT: Shrine uses "event.shrine" format, NOT "shrine.event"!
          notification_name = "#{event_name}.shrine"

          # Unsubscribe existing listeners and subscribe our new one
          ::ActiveSupport::Notifications.unsubscribe(notification_name)
          ::ActiveSupport::Notifications.subscribe(notification_name) do |*args|
            event = ::ActiveSupport::Notifications::Event.new(*args)
            new_subscriber.call(event)
          end
          LogStruct::Debug.log(:shrine, "  #{notification_name}: replaced subscriber")
        end

        LogStruct::Debug.log(:shrine, "replace_existing_subscribers finished")
      end
    end
  end
end
