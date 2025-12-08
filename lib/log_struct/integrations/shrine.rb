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

      sig { returns(T::Boolean) }
      def self.debug_enabled?
        ENV["LOGSTRUCT_DEBUG"] == "true"
      end

      sig { params(msg: String).void }
      def self.debug_log(msg)
        return unless debug_enabled?

        warn "[LOGSTRUCT_DEBUG] [Shrine] #{msg}"
      end

      # Set up Shrine structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        debug_log "setup called"
        debug_log "  defined?(::Shrine) = #{defined?(::Shrine).inspect}"
        debug_log "  config.enabled = #{config.enabled}"
        debug_log "  config.integrations.enable_shrine = #{config.integrations.enable_shrine}"

        unless defined?(::Shrine)
          debug_log "  RETURNING NIL: ::Shrine not defined"
          return nil
        end
        unless config.enabled
          debug_log "  RETURNING NIL: config not enabled"
          return nil
        end
        unless config.integrations.enable_shrine
          debug_log "  RETURNING NIL: shrine integration not enabled"
          return nil
        end

        debug_log "  All checks passed, setting up Shrine subscriber"

        # Create a structured log subscriber for Shrine
        # ActiveSupport::Notifications::Event has name, time, end, transaction_id, payload, and duration
        shrine_log_subscriber = T.unsafe(lambda do |event|
          if ENV["LOGSTRUCT_DEBUG"] == "true"
            warn "[LOGSTRUCT_DEBUG] [Shrine] SUBSCRIBER CALLED!"
            warn "[LOGSTRUCT_DEBUG] [Shrine]   event.name = #{event.name}"
            warn "[LOGSTRUCT_DEBUG] [Shrine]   event.payload.keys = #{event.payload.keys}"
          end

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
        debug_log "  instrumentation_already_configured? = #{already_configured}"

        if already_configured
          debug_log "  PATH: Replacing existing subscribers"
          replace_existing_subscribers(shrine_log_subscriber)
        else
          debug_log "  PATH: First time setup - calling Shrine.plugin :instrumentation"
          # First time setup - configure the instrumentation plugin
          ::Shrine.plugin :instrumentation,
            events: SHRINE_EVENTS,
            log_subscriber: shrine_log_subscriber
        end

        debug_log "  Setup complete"
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
        debug_log "replace_existing_subscribers called"

        opts = T.unsafe(::Shrine).opts
        instrumentation_opts = opts[:instrumentation]

        debug_log "  instrumentation_opts.keys = #{instrumentation_opts.keys.inspect}"
        debug_log "  instrumentation_opts[:log_subscriber] = #{instrumentation_opts[:log_subscriber].inspect[0..100]}"
        debug_log "  instrumentation_opts[:log_events] = #{instrumentation_opts[:log_events].inspect}"

        # CRITICAL: Replace the log_subscriber option itself.
        # This is what produces the "Upload (Xms) – {storage: ...}" format.
        # If we don't replace this, Shrine's default subscriber still runs.
        instrumentation_opts[:log_subscriber] = new_subscriber
        debug_log "  Replaced :log_subscriber with our subscriber"

        # Ensure subscribers hash exists
        instrumentation_opts[:subscribers] ||= {}
        subscribers = T.cast(instrumentation_opts[:subscribers], T::Hash[Symbol, T::Array[T.untyped]])
        debug_log "  subscribers.keys = #{subscribers.keys.inspect}"
        debug_log "  subscribers BEFORE replacement:"
        subscribers.each do |event_name, subs|
          debug_log "    #{event_name}: #{subs.size} subscribers"
          subs.each_with_index { |s, i| debug_log "      [#{i}] #{s.inspect[0..80]}" }
        end

        # Check ALL AS::Notifications subscribers for shrine events
        debug_log "  Checking AS::Notifications for all shrine.* patterns..."
        notifier = ::ActiveSupport::Notifications.notifier
        debug_log "    Notifier class: #{notifier.class}"
        debug_log "    Notifier methods: #{notifier.public_methods(false).sort.join(", ")}"

        # Try to access internal subscriber storage
        instance_vars = notifier.instance_variables
        debug_log "    Notifier instance_vars: #{instance_vars.inspect}"
        instance_vars.each do |var_name|
          val = notifier.instance_variable_get(var_name)
          if val.respond_to?(:each) && !val.is_a?(String)
            debug_log "    #{var_name}: #{val.class} with #{begin
              val.size
            rescue
              "?"
            end} items"
          end
        end

        # Check listeners_for with different patterns
        # IMPORTANT: Shrine uses "event.shrine" format, NOT "shrine.event"!
        ["upload.shrine", "shrine.upload", /shrine/].each do |pattern|
          if notifier.respond_to?(:listeners_for)
            listeners = begin
              notifier.listeners_for(pattern)
            rescue
              []
            end
            debug_log "    listeners_for(#{pattern.inspect}): #{listeners.size} listeners"
          end
        end

        # Clear all existing subscribers and add our new one
        SHRINE_EVENTS.each do |event_name|
          # Clear existing subscribers for this event and add our new one
          subscribers[event_name] = [new_subscriber]

          # Also re-subscribe via ActiveSupport::Notifications
          # IMPORTANT: Shrine uses "event.shrine" format, NOT "shrine.event"!
          notification_name = "#{event_name}.shrine"

          # Unsubscribe existing listeners for this event
          # ActiveSupport::Notifications stores subscriptions - we need to unsubscribe by name
          # which removes ALL subscribers for this event name
          debug_log "  #{notification_name}: unsubscribing all existing listeners by name..."
          ::ActiveSupport::Notifications.unsubscribe(notification_name)

          # Verify listeners were removed
          notifier = ::ActiveSupport::Notifications.notifier
          if notifier.respond_to?(:listeners_for)
            remaining = notifier.listeners_for(notification_name)
            debug_log "  #{notification_name}: #{remaining.size} listeners remain after unsubscribe"
          end

          # Subscribe our new subscriber
          ::ActiveSupport::Notifications.subscribe(notification_name) do |*args|
            event = ::ActiveSupport::Notifications::Event.new(*args)
            new_subscriber.call(event)
          end
          debug_log "  #{notification_name}: subscribed our new listener"

          # Verify subscription worked
          if notifier.respond_to?(:listeners_for)
            after_sub = notifier.listeners_for(notification_name)
            debug_log "  #{notification_name}: #{after_sub.size} listeners after subscribing our listener"
          end
        end

        debug_log "  subscribers AFTER replacement:"
        subscribers.each do |event_name, subs|
          debug_log "    #{event_name}: #{subs.size} subscribers - #{subs.first.inspect[0..80]}"
        end

        # Check if subclasses have their own opts
        debug_log "  Checking uploader subclasses..."
        ::Shrine.subclasses.each do |subclass|
          sub_opts = subclass.opts[:instrumentation]
          if sub_opts
            debug_log "    #{subclass.name}: has instrumentation opts"
            debug_log "      subscribers.keys = #{sub_opts[:subscribers]&.keys.inspect}"
            debug_log "      Same as Shrine.opts? #{sub_opts[:subscribers].equal?(subscribers)}"
          else
            debug_log "    #{subclass.name}: no instrumentation opts"
          end
        end

        debug_log "replace_existing_subscribers finished"
      end
    end
  end
end
