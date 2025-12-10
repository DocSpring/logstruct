# typed: strict
# frozen_string_literal: true

begin
  require "lograge"
rescue LoadError
  # Lograge gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # Lograge integration for structured request logging
    module Lograge
      extend IntegrationInterface

      class << self
        extend T::Sig

        sig { returns(T::Boolean) }
        def debug_enabled?
          ENV["LOGSTRUCT_DEBUG"] == "true"
        end

        sig { params(msg: String).void }
        def debug_log(msg)
          return unless debug_enabled?

          warn "[LOGSTRUCT_DEBUG] [Lograge] #{msg}"
        end

        # Set up lograge for structured request logging
        sig { override.params(logstruct_config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
        def setup(logstruct_config)
          debug_log "setup called"
          debug_log "  defined?(::Lograge) = #{defined?(::Lograge).inspect}"
          debug_log "  logstruct_config.enabled = #{logstruct_config.enabled}"
          debug_log "  logstruct_config.integrations.enable_lograge = #{logstruct_config.integrations.enable_lograge}"

          unless defined?(::Lograge)
            debug_log "  RETURNING NIL: ::Lograge not defined"
            return nil
          end
          unless logstruct_config.enabled
            debug_log "  RETURNING NIL: logstruct not enabled"
            return nil
          end
          unless logstruct_config.integrations.enable_lograge
            debug_log "  RETURNING NIL: lograge integration not enabled"
            return nil
          end

          debug_log "  All checks passed, calling configure_lograge"
          debug_log "  BEFORE configure_lograge:"
          debug_log "    ::Lograge.logger = #{::Lograge.logger.inspect}"
          debug_log "    ::Lograge.logger.class = #{::Lograge.logger.class}" if ::Lograge.logger
          debug_log "    ::Rails.logger = #{::Rails.logger.inspect}"
          debug_log "    ::Rails.logger.class = #{::Rails.logger.class}"

          configure_lograge(logstruct_config)

          debug_log "  AFTER configure_lograge:"
          debug_log "    ::Lograge.logger = #{::Lograge.logger.inspect}"
          debug_log "    ::Lograge.logger.class = #{::Lograge.logger.class}" if ::Lograge.logger
          debug_log "    ::Lograge.enabled = #{begin
            ::Lograge.application&.config&.lograge&.enabled
          rescue
            "ERROR"
          end}"
          debug_log "    config.lograge.enabled = #{begin
            ::Rails.application.config.lograge.enabled
          rescue
            "ERROR"
          end}"
          debug_log "    config.lograge.formatter = #{begin
            ::Rails.application.config.lograge.formatter.inspect
          rescue
            "ERROR"
          end}"

          # Check if Lograge has attached its subscriber
          debug_log "  Checking ActionController subscribers..."
          begin
            subscribers = ::ActiveSupport::Notifications.notifier.listeners_for("process_action.action_controller")
            debug_log "    process_action.action_controller subscribers count: #{subscribers.size}"
            subscribers.each_with_index do |sub, idx|
              debug_log "    [#{idx}] #{sub.class}: #{sub.inspect[0..200]}"
            end
          rescue => e
            debug_log "    ERROR checking subscribers: #{e.message}"
          end

          true
        end

        private_class_method

        sig { params(logstruct_config: LogStruct::Configuration).void }
        def configure_lograge(logstruct_config)
          debug_log "configure_lograge called"

          ::Rails.application.configure do
            # IMPORTANT: Do NOT set config.lograge.enabled = true here!
            # Lograge's railtie checks this in after_initialize and calls Lograge.setup() if true.
            # We call Lograge.setup() ourselves below, so setting enabled=true would cause
            # duplicate subscriber attachment (and duplicate request logs).
            # We configure everything manually and call setup ourselves.

            config.lograge.logger = ::Rails.logger
            ::Lograge.logger = ::Rails.logger

            # Use a raw formatter that just returns the log struct.
            # The struct is converted to JSON by our Formatter (after filtering, etc.)
            config.lograge.formatter = T.let(
              lambda do |data|
                # Coerce common fields to expected types
                status = ((s = data[:status]) && s.respond_to?(:to_i)) ? s.to_i : s
                duration_ms = ((d = data[:duration]) && d.respond_to?(:to_f)) ? d.to_f : d
                view = ((v = data[:view]) && v.respond_to?(:to_f)) ? v.to_f : v
                db = ((b = data[:db]) && b.respond_to?(:to_f)) ? b.to_f : b

                params = data[:params]
                params = params.deep_symbolize_keys if params&.respond_to?(:deep_symbolize_keys)

                request_log = Log::Request.new(
                  http_method: data[:method]&.to_s,
                  path: data[:path]&.to_s,
                  format: data[:format]&.to_sym,
                  controller: data[:controller]&.to_s,
                  action: data[:action]&.to_s,
                  status: status,
                  duration_ms: duration_ms,
                  view: view,
                  database: db,
                  params: params,
                  timestamp: Time.now
                )

                if ENV["LOGSTRUCT_DEBUG"] == "true"
                  warn "[LOGSTRUCT_DEBUG] [Lograge]   Created Log::Request: #{request_log.inspect}"
                end

                request_log
              end,
              T.proc.params(hash: T::Hash[Symbol, T.untyped]).returns(Log::Request)
            )

            # Add custom options to lograge
            config.lograge.custom_options = lambda do |event|
              if ENV["LOGSTRUCT_DEBUG"] == "true"
                warn "[LOGSTRUCT_DEBUG] [Lograge] custom_options called!"
                warn "[LOGSTRUCT_DEBUG] [Lograge]   event.name = #{event.name}"
                warn "[LOGSTRUCT_DEBUG] [Lograge]   event.payload.keys = #{event.payload.keys}"
              end
              Integrations::Lograge.lograge_default_options(event)
            end
          end

          # NOW call Lograge.setup() to attach the ActionController subscriber.
          # This MUST happen after all config is set, and we do it ourselves
          # because we did NOT set config.lograge.enabled=true (to prevent Lograge's
          # railtie from also calling setup and causing duplicates).
          debug_log "Calling ::Lograge.setup(::Rails.application)..."
          ::Lograge.setup(::Rails.application)
          debug_log "::Lograge.setup complete"

          debug_log "configure_lograge finished"
        end

        sig { params(event: ActiveSupport::Notifications::Event).returns(T::Hash[Symbol, T.untyped]) }
        def lograge_default_options(event)
          # Extract essential fields from the payload
          options = event.payload.slice(
            :request_id,
            :host,
            :source_ip
          ).compact

          if event.payload[:params].present?
            options[:params] = event.payload[:params].except("controller", "action")
          end

          # Process headers if available
          process_headers(event, options)

          # Apply custom options from application if provided
          apply_custom_options(event, options)

          options
        end

        # Process headers from the event payload
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def process_headers(event, options)
          headers = event.payload[:headers]
          return if headers.blank?

          options[:user_agent] = headers["HTTP_USER_AGENT"]
          options[:content_type] = headers["CONTENT_TYPE"]
          options[:accept] = headers["HTTP_ACCEPT"]
        end

        # Apply custom options from the application's configuration
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def apply_custom_options(event, options)
          custom_options_proc = LogStruct.config.integrations.lograge_custom_options
          return unless custom_options_proc&.respond_to?(:call)

          # Call the proc with the event and options
          # The proc can modify the options hash directly
          custom_options_proc.call(event, options)
        end
      end
    end
  end
end
