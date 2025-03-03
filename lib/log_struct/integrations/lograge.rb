# typed: true
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
      class << self
        # Set up lograge for structured request logging
        def setup
          return unless defined?(::Lograge)

          ::Rails.application.configure do
            config.lograge.enabled = true
            # Use a raw formatter that just returns the log struct.
            # The struct is converted to JSON by our JSONFormatter (after filtering, etc.)
            config.lograge.formatter = T.let(
              lambda do |data|
                # Convert the data hash to a Log::Request struct
                Log::Request.new(
                  src: LogSource::Rails,
                  evt: LogEvent::Request,
                  ts: T.cast(Time.now, Time),
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

          # We'll set these in the formatter
          # options[:src] = LogSource::Rails
          # options[:evt] = LogEvent::Request

          if event.payload[:params].present?
            options[:params] = event.payload[:params].except("controller", "action")
          end

          # Process headers if available
          process_headers(event, options)

          # Apply custom options from application if provided
          apply_custom_options(event, options)

          options
        end

        private

        # Process headers from the event payload
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
        def apply_custom_options(event, options)
          custom_options_proc = LogStruct.config.lograge_custom_options
          return unless custom_options_proc&.respond_to?(:call)

          # Call the proc with the event and options
          # The proc can modify the options hash directly
          custom_options_proc.call(event, options)
        end
      end
    end
  end
end
