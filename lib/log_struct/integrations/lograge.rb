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
          return nil unless defined?(::Lograge)
          return nil unless logstruct_config.enabled
          return nil unless logstruct_config.integrations.enable_lograge

          configure_lograge(logstruct_config)

          # Lograge's railtie calls Lograge.setup(app) in config.after_initialize,
          # which runs AFTER our initializer. Since we set config.lograge.enabled = true
          # in configure_lograge, Lograge's railtie will see it and call setup for us.

          true
        end

        private_class_method

        sig { params(logstruct_config: LogStruct::Configuration).void }
        def configure_lograge(logstruct_config)
          ::Rails.application.configure do
            config.lograge.enabled = true
            # We must set BOTH config.lograge.logger AND ::Lograge.logger directly.
            # Lograge's railtie copies config.lograge.logger to ::Lograge.logger during init,
            # but that runs BEFORE our integration setup. So ::Lograge.logger is nil.
            # Lograge's subscriber uses `Lograge.logger.presence || super` - without setting
            # the class attribute directly, it falls back to super (wrong logger).
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

                request_log
              end,
              T.proc.params(hash: T::Hash[Symbol, T.untyped]).returns(Log::Request)
            )

            # Add custom options to lograge
            config.lograge.custom_options = lambda do |event|
              Integrations::Lograge.lograge_default_options(event)
            end
          end
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
