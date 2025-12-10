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

        # Set up lograge for structured request logging
        sig { override.params(logstruct_config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
        def setup(logstruct_config)
          LogStruct::Debug.log(:lograge, "setup called")
          LogStruct::Debug.log(:lograge, "  defined?(::Lograge) = #{defined?(::Lograge).inspect}")
          LogStruct::Debug.log(:lograge, "  logstruct_config.enabled = #{logstruct_config.enabled}")
          LogStruct::Debug.log(:lograge, "  logstruct_config.integrations.enable_lograge = #{logstruct_config.integrations.enable_lograge}")

          unless defined?(::Lograge)
            LogStruct::Debug.log(:lograge, "  RETURNING NIL: ::Lograge not defined")
            return nil
          end
          unless logstruct_config.enabled
            LogStruct::Debug.log(:lograge, "  RETURNING NIL: logstruct not enabled")
            return nil
          end
          unless logstruct_config.integrations.enable_lograge
            LogStruct::Debug.log(:lograge, "  RETURNING NIL: lograge integration not enabled")
            return nil
          end

          LogStruct::Debug.log(:lograge, "  All checks passed, calling configure_lograge")
          LogStruct::Debug.log(:lograge, "  BEFORE configure_lograge:")
          LogStruct::Debug.log(:lograge, "    ::Lograge.logger = #{::Lograge.logger.inspect}")
          LogStruct::Debug.log(:lograge, "    ::Lograge.logger.class = #{::Lograge.logger.class}") if ::Lograge.logger
          LogStruct::Debug.log(:lograge, "    ::Rails.logger = #{::Rails.logger.inspect}")
          LogStruct::Debug.log(:lograge, "    ::Rails.logger.class = #{::Rails.logger.class}")

          configure_lograge(logstruct_config)

          LogStruct::Debug.log(:lograge, "  AFTER configure_lograge:")
          LogStruct::Debug.log(:lograge, "    ::Lograge.logger = #{::Lograge.logger.inspect}")
          LogStruct::Debug.log(:lograge, "    ::Lograge.logger.class = #{::Lograge.logger.class}") if ::Lograge.logger

          true
        end

        private_class_method

        sig { params(logstruct_config: LogStruct::Configuration).void }
        def configure_lograge(logstruct_config)
          LogStruct::Debug.log(:lograge, "configure_lograge called")

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

                LogStruct::Debug.log(:lograge, "  Created Log::Request: #{request_log.inspect}")

                request_log
              end,
              T.proc.params(hash: T::Hash[Symbol, T.untyped]).returns(Log::Request)
            )

            # Add custom options to lograge
            config.lograge.custom_options = lambda do |event|
              LogStruct::Debug.log(:lograge, "custom_options called, event.name=#{event.name}")
              Integrations::Lograge.lograge_default_options(event)
            end
          end

          # NOW call Lograge.setup() to attach the ActionController subscriber.
          # This MUST happen after all config is set, and we do it ourselves
          # because we did NOT set config.lograge.enabled=true (to prevent Lograge's
          # railtie from also calling setup and causing duplicates).
          LogStruct::Debug.log(:lograge, "Calling ::Lograge.setup(::Rails.application)...")
          ::Lograge.setup(::Rails.application)
          LogStruct::Debug.log(:lograge, "::Lograge.setup complete")
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
