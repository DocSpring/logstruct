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
        sig { override.params(logstruct_config: LogStruct::Configuration).void }
        def setup(logstruct_config)
          return unless defined?(::Lograge)
          return unless logstruct_config.enabled
          return unless logstruct_config.integrations.enable_lograge

          configure_lograge(logstruct_config)
        end

        private_class_method

        sig { params(logstruct_config: LogStruct::Configuration).void }
        def configure_lograge(logstruct_config)
          ::Rails.application.configure do
            config.lograge.enabled = true
            # Use a raw formatter that just returns the log struct.
            # The struct is converted to JSON by our Formatter (after filtering, etc.)
            config.lograge.formatter = T.let(
              lambda do |data|
                # Convert the data hash to a Log::Request struct
                Log::Request.new(
                  source: Source::Request,
                  event: LogEvent::Request,
                  timestamp: Time.now,
                  http_method: data[:method],
                  path: data[:path],
                  format: data[:format],
                  controller: data[:controller],
                  action: data[:action],
                  status: data[:status],
                  duration: data[:duration],
                  view: data[:view],
                  db: data[:db],
                  params: data[:params]
                )
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

          options[:basic_auth] = true if headers["basic_auth"]
          return unless options[:basic_auth]

          # Include API token information for debugging authentication
          options[:basic_auth_username] = headers["basic_auth.username"]
          options[:basic_auth_password] = headers["basic_auth.password"]
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
